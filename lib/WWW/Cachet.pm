package WWW::Cachet;
our $VERSION = '0.01';

=head1 NAME

WWW::Cachet - Perl extension to interface with Cachet L<http://cachethq.io/>

=head1 SYNOPSIS

  use WWW::Cachet;
  # Import some constants to use later
  use WWW::Cachet::Const qw/ :all :component_status :incident_status :calc_type /;

  my $cachet = WWW::Cachet->new(
    api_url   => "http://cachet.example.com/api/v1",
    api_token => "rRpHYVhsNnG12X3N4ufr",
    # Optional basic HTTP authentication
    basic_auth => {
      user     => "cachet",
      password => "test"
    }
  );

  # Retrieve all components
  my $components = $cachet->getComponents();
  print $_->name, "\n" for (@{$components});

  # Retrieve all components with status STATUS_MAJOR_OUTAGE
  my $components = $cachet->getComponents({ status => STATUS_MAJOR_OUTAGE });
  print $_->name, "\n" for (@{$components});

  # Retrieve a single component
  my $component = $cachet->getComponent(1);
  die $cachet->error unless($component);

  # Create a component
  my $new_component = $cachet->addComponent({
    name => "New Component",
    status => STATUS_OPERATIONAL
  });

  # Update an existing component
  $new_component->status(STATUS_PARTIAL_OUTAGE);
  my $updated_component = $cachet->updateComponent($new_component);
  # OR
  my $id = 3;
  my %update = ( status => STATUS_PARTIAL_OUTAGE );
  my $updated_component = $cachet->updateComponent($id, \%update);

=head1 DESCRIPTION

Simple interface to Cachet from Perl. Available methods are documented here in POD,
required/available parameters can be found in subclasses of WWW::Cachet::Object.
Alternatively you can check the API docs at L<https://docs.cachethq.io/reference> as
arguments are 1 for 1 translated to function parameters.

=head1 METHODS
=cut


use constant TRUE  => 1;
use constant FALSE => 0;

use Moo;
use Carp;
use JSON;
use URI;
use LWP::UserAgent;
use HTTP::Request::Common qw/ GET POST PUT DELETE /;
use HTTP::Status qw/ status_message /;

use WWW::Cachet::Response;
use WWW::Cachet::Component;
use WWW::Cachet::ComponentGroup;
use WWW::Cachet::Incident;
use WWW::Cachet::Metric;
use WWW::Cachet::MetricPoint;
use WWW::Cachet::Subscriber;

has api_url => (
  is => 'rw',
  required => TRUE,
);

has api_token => (
  is => 'rw',
  required => TRUE,
);

has basic_auth => (
  is => 'rw',
);

has _ua => (
  is => 'rw'
);

=head2 General

=head3 error()
  
  Returns the last encountered error message as a string

=cut
has error => (
  is => 'rw'
);

sub BUILD {
  my ($self, $args) = @_;

  if (defined $args->{basic_auth}) {
    if (ref $args->{basic_auth} ne "HASH") {
      confess "WWW::Cachet basic_auth parameter should be a hashref";
    }

    if (!defined $args->{basic_auth}->{user} || !defined $args->{basic_auth}->{password}) {
      confess "WWW::Cachet basic_auth hash should contain `user` and `password`";
    }
  }

  $self->_ua( defined $args->{_ua} ? $args->{_ua} : new LWP::UserAgent);
  $self->_ua->default_header("X-Cachet-Token" => $self->api_token);
}

=head3 ping()

  Test that the API is responding to your requests

=cut
sub ping {
  my ($self) = @_;
  
  my $response = $self->_get("/ping");  
  return $response->ok;
}

=head3 getVersion()

  Get Cachet version from API

=cut
sub getVersion {
  my ($self) = @_;
  
  my $response = $self->_get("/version");
  if ($response->ok) {
    return $response->data;
  }
  return undef;
}

=head2 Components

=head3 getComponents(\%params)

  Returns a list of WWW::Cachet::Component from the Cachet API

=cut
sub getComponents {
  my ($self, $params) = @_;
  my $response = $self->_get("/components", $params);
  if ($response->ok) {
    my @components = ();
    for my $c (@{$response->data}) {
      push @components, WWW::Cachet::Component->new( $c );
    }
    return \@components
  }
  return undef;
}

=head3 getComponent($id)

  Return a single WWW::Cachet::Component from the Cachet API

=cut
sub getComponent {
  my ($self, $id) = @_;
  
  my $response = $self->_get("/components/$id");
  if ($response->ok) {
    return WWW::Cachet::Component->new( $response->data );
  }
  return undef;
}

=head3 addComponent($data)

  Requires valid authentication
  Create a new component

=cut
sub addComponent {
  my ($self, $component) = @_;

  if (ref $component eq "WWW::Cachet::Component") {
    $component = $component->toHash();
  }

  # Including a tags key in the request will cause a 500 Internal Server Error
  delete($component->{tags});

  my $response = $self->_post("/components", $component);
  if ($response->ok) {
    return WWW::Cachet::Component->new($response->data);
  }

  return undef;
}

=head3 updateComponent($id, $data)

  Requires valid authentication
  Update a component

=cut
sub updateComponent {
  my ($self, $id, $component) = @_;

  if (ref $id eq "WWW::Cachet::Component" && $id->id) {
    $component = $id;
    $id = $component->id;
  }

  if (ref $component eq "WWW::Cachet::Component") {
    $component = $component->toHash();
  }

  # Including a tags key in the request will cause a 500 Internal Server Error
  delete($component->{tags});

  my $response = $self->_put("/components/$id", $component);
  if ($response->ok) {
    return WWW::Cachet::Component->new($response->data);
  }

  return undef;
}


=head3 deleteComponent($id)

  Requires valid authentication
  Delete a component

=cut
sub deleteComponent {
  my ($self, $id) = @_;
  
  my $response = $self->_delete("/components/$id");
  return $response->ok;
}

=head2 Component Groups

=head3 getComponentGroups(\%params)

  Returns a list of WWW::Cachet::ComponentGroup from the Cachet API

=cut
sub getComponentGroups {
  my ($self, $params) = @_;
  
  my $response = $self->_get("/components/groups", $params);
  if ($response->ok) {
    my @groups = ();
    for my $c (@{$response->data}) {
      push @groups, WWW::Cachet::ComponentGroup->new( $c );
    }
    return \@groups
  }
  return undef;
}

=head3 getComponentGroup($id)

  Return a single WWW::Cachet::ComponentGroup from the Cachet API

=cut
sub getComponentGroup {
  my ($self, $id) = @_;
  
  my $response = $self->_get("/components/groups/$id");
  if ($response->ok) {
    return WWW::Cachet::ComponentGroup->new( $response->data );
  }
  return undef;
}

=head3 addComponentGroup($data)

  Requires valid authentication
  Create a new component group

=cut
sub addComponentGroup {
  my ($self, $group) = @_;

  if (ref $group eq "WWW::Cachet::ComponentGroup") {
    $group = $group->toHash();
  }

  my $response = $self->_post("/components/groups", $group);
  if ($response->ok) {
    return WWW::Cachet::ComponentGroup->new($response->data);
  }

  return undef;
}

=head3 updateComponentGroup($id, $data)

  Requires valid authentication
  Update a component group

=cut
sub updateComponentGroup {
  my ($self, $id, $group) = @_;

  if (ref $id eq "WWW::Cachet::ComponentGroup" && $id->id) {
    $group = $id;
    $id = $group->id;
  }

  if (ref $group eq "WWW::Cachet::ComponentGroup") {
    $group = $group->toHash();
  }

  my $response = $self->_put("/components/groups/$id", $group);
  if ($response->ok) {
    return WWW::Cachet::ComponentGroup->new($response->data);
  }

  return undef;
}


=head3 deleteComponentGroup($id)

  Requires valid authentication
  Delete a component group

=cut
sub deleteComponentGroup {
  my ($self, $id) = @_;
  
  my $response = $self->_delete("/components/groups/$id");
  return $response->ok;
}

=head2 Incidents

=head3 getIncidents(\%params)

  Returns a list of WWW::Cachet::Incident from the Cachet API

=cut
sub getIncidents {
  my ($self, $params) = @_;
  
  my $response = $self->_get("/incidents", $params);
  if ($response->ok) {
    my @incidents = ();
    for my $c (@{$response->data}) {
      push @incidents, WWW::Cachet::Incident->new( $c );
    }
    return \@incidents
  }
  return undef;
}

=head3 getIncident($id)

  Return a single WWW::Cachet::Incident from the Cachet API

=cut
sub getIncident {
  my ($self, $id) = @_;
  
  my $response = $self->_get("/incidents/$id");
  if ($response->ok) {
    return WWW::Cachet::Incident->new( $response->data );
  }
  return undef;
}

=head3 addIncident($data)

  Requires valid authentication
  Create a new component

=cut
sub addIncident {
  my ($self, $incident) = @_;

  if (ref $incident eq "WWW::Cachet::Incident") {
    $incident = $incident->toHash();
  }

  # We receive a 400 Bad Request if a component_id is set without a
  # component_status
  delete($incident->{component_id})
    unless (exists($incident->{component_status}));

  my $response = $self->_post("/incidents", $incident);
  if ($response->ok) {
    return WWW::Cachet::Incident->new($response->data);
  }

  return undef;
}

=head3 updateIncident($id, $data)

  Requires valid authentication
  Update a incident

=cut
sub updateIncident {
  my ($self, $id, $incident) = @_;

  if (ref $id eq "WWW::Cachet::Incident" && $id->id) {
    $incident = $id;
    $id = $incident->id;
  }

  if (ref $incident eq "WWW::Cachet::Incident") {
    $incident = $incident->toHash();
  }

  # Including a created_at key in the request will cause a 500 Internal Server
  # Error
  delete($incident->{created_at});

  # We receive a 400 Bad Request if a component_id is set without a
  # component_status
  delete($incident->{component_id})
    unless (exists($incident->{component_status}));

  my $response = $self->_put("/incidents/$id", $incident);
  if ($response->ok) {
    return WWW::Cachet::Incident->new($response->data);
  }

  return undef;
}


=head3 deleteIncident($id)

  Requires valid authentication
  Delete a incident

=cut
sub deleteIncident {
  my ($self, $id) = @_;
  
  my $response = $self->_delete("/incidents/$id");
  return $response->ok;
}


=head2 Metrics

=head3 getMetrics()

  Returns a list of WWW::Cachet::Metric from the Cachet API

=cut
sub getMetrics {
  my ($self) = @_;
  
  my $response = $self->_get("/metrics");
  if ($response->ok) {
    my @metrics = ();
    for my $c (@{$response->data}) {
      push @metrics, WWW::Cachet::Metric->new( $c );
    }
    return \@metrics
  }
  return undef;
}

=head3 getMetric($id)

  Return a single WWW::Cachet::Metric from the Cachet API

=cut
sub getMetric {
  my ($self, $id) = @_;
  
  my $response = $self->_get("/metrics/$id");
  if ($response->ok) {
    return WWW::Cachet::Metric->new( $response->data );
  }
  return undef;
}

=head3 addMetric($data)

  Requires valid authentication
  Create a new component

=cut
sub addMetric {
  my ($self, $metric) = @_;

  if (ref $metric eq "WWW::Cachet::Metric") {
    $metric = $metric->toHash();
  }

  my $response = $self->_post("/metrics", $metric);
  if ($response->ok) {
    return WWW::Cachet::Metric->new($response->data);
  }

  return undef;
}

=head3 updateMetric($id, $data)

  Requires valid authentication
  Update a metric

=cut
sub updateMetric {
   my ($self, $id, $metric) = @_;

  if (ref $id eq "WWW::Cachet::Metric" && $id->id) {
    $metric = $id;
    $id = $metric->id;
  }

  if (ref $metric eq "WWW::Cachet::Metric") {
    $metric = $metric->toHash();
  }

  my $response = $self->_put("/metrics/$id", $metric);
  if ($response->ok) {
    return WWW::Cachet::Metric->new($response->data);
  }

  return undef;
}


=head3 deleteMetric($id)

  Requires valid authentication
  Delete a metric

=cut
sub deleteMetric {
  my ($self, $id) = @_;
  
  my $response = $self->_delete("/metrics/$id");
  return $response->ok;
}

=head2 Metric Points

=head3 getMetricPoints($metric)

  Returns a list of WWW::Cachet::MetricPoints from the Cachet API

=cut
sub getMetricPoints {
  my ($self, $id) = @_;

  if (ref $id eq "WWW::Cachet::Metric") {
    $id = $id->id;
  }
  
  my $response = $self->_get("/metrics/$id/points");
  if ($response->ok) {
    my @metrics = ();
    for my $c (@{$response->data}) {
      push @metrics, WWW::Cachet::MetricPoint->new( $c );
    }
    return \@metrics
  }
  return undef;
}

=head3 addMetricPoint($metric_id, $point_data)
   addMetricPoint($metric, $point)
   addMetricPoint($point)

  Requires valid authentication
  Create a new component

=cut
sub addMetricPoint {
  my ($self, $metric, $point) = @_;

  if (ref $metric eq "WWW::Cachet::Metric") {
    $metric = $metric->id;
  } elsif (ref $metric eq "WWW::Cachet::MetricPoint" && $metric->metric_id) {
    $point = $metric;
    $metric = $point->metric_id;
  }

  if (ref $point eq "WWW::Cachet::MetricPoint") {
    $point = $point->toHash();
  }

  my $response = $self->_post("/metrics/$metric/points", $point);
  if ($response->ok) {
    return WWW::Cachet::MetricPoint->new($response->data);
  }

  return undef;
}

=head3 deleteMetricPoint($metric_id, $point_id)
   deleteMetricPoint($metric, $point)
   deleteMetricPoint($point) # Provided point has metric_id set

  Requires valid authentication
  Delete a metric

=cut
sub deleteMetricPoint {
  my ($self, $metric, $point) = @_;

  if (ref $metric eq "WWW::Cachet::Metric") {
    $metric = $metric->id;
  } elsif (ref $metric eq "WWW::Cachet::MetricPoint" && $metric->metric_id) {
    $point = $metric;
    $metric = $point->metric_id;
  }

  if (ref $point eq "WWW::Cachet::MetricPoint") {
    $point = $point->id;
  }
  
  my $response = $self->_delete("/metrics/$metric/points/$point");
  return $response->ok;
}


=head2 Subscribers

=head3 getSubscribers()

  Returns a list of WWW::Cachet::Subscribers from the Cachet API

=cut
sub getSubscribers {
  my ($self) = @_;

  my $response = $self->_get("/subscribers");
  if ($response->ok) {
    my @metrics = ();
    for my $c (@{$response->data}) {
      push @metrics, WWW::Cachet::Subscriber->new( $c );
    }
    return \@metrics
  }
  return undef;
}

=head3 addSubscriber($data)
   addSubscriber(WWW::Cachet::Subscriber)

  Requires valid authentication
  Create a new subscriber

  TODO: Can't currently set component alerts to subscribe to (always ALL)

=cut
sub addSubscriber {
  my ($self, $data) = @_;

  if (ref $data eq "WWW::Cachet::Subscriber") {
    $data = $data->toHash();
  }

  my $response = $self->_post("/subscribers", $data);
  if ($response->ok) {
    return WWW::Cachet::Subscriber->new($response->data);
  }

  return undef;
}

=head3 deleteSubscriber($subscriber_id)
   deleteSubscriber(WWW::Cachet::Subscriber)

  Requires valid authentication
  Delete a metric

=cut
sub deleteSubscriber {
  my ($self, $subscriber) = @_;

  if (ref $subscriber eq "WWW::Cachet::Subscriber") {
    $subscriber = $subscriber->id;
  }
  
  my $response = $self->_delete("/subscribers/$subscriber");
  return $response->ok;
}


##
#
# BEGIN secret undocumented internals. Woo
#
##
sub _get {
  my ($self, $path, $params) = @_;
  # Build a uri with get params if they were passed in
  my $uri = URI->new( $self->api_url . $path );
  $uri->query_form($params) if ($params);
  # Be a man, do the food
  my $request = GET $uri;
  return $self->_handle_response($request);
}

sub _post {
  my ($self, $path, $params) = @_;
  my $url = $self->api_url . $path;
  my $request = POST $url, 'Content-Type' => 'application/json', Content => encode_json($params);
  return $self->_handle_response($request);
}

sub _put {
  my ($self, $path, $params) = @_;
  my $url = $self->api_url . $path;
  my $request = PUT $url, 'Content-Type' => 'application/json', Content => encode_json($params);
  return $self->_handle_response($request);
}

sub _delete {
  my ($self, $path) = @_;
  my $url = $self->api_url . $path;
  my $request = DELETE $url;
  return $self->_handle_response($request);
}

# Handles the response, yes, but also actually does the HTTP request to API
# Name could do with a bit more thought.
sub _handle_response {
  my ($self, $req) = @_;

  if ($self->basic_auth) {
    $req->authorization_basic( $self->basic_auth->{user}, $self->basic_auth->{password} );
  }

  my $res = $self->_ua->request($req);

  my $response;
  if ($res->is_success) {
    my $json;
    if ($res->content) {
       $json = decode_json $res->content;
    }

    $response = WWW::Cachet::Response->new(
      ok => TRUE,
      data => $json ? $json->{data} : undef
    );

  } elsif ($res->code == 401) {
    $self->error("API Authentication is required and has failed");
    $response = WWW::Cachet::Response->new( ok => FALSE, message => $self->error );

  } elsif ($res->code == 404) {
    $self->error("Requested resource not found");
    $response = WWW::Cachet::Response->new( ok => FALSE, message => $self->error );

  } else {
    # Gather error message(s)
    my @errors = ();
    if ($res->content) {
      my $json = decode_json $res->content;
      for my $e (@{ $json->{errors} }) {
        push @errors, "$e->{title}: $e->{detail}";
      }
    } else {
      push @errors, status_message($res->code);
    }

    $self->error( join("; ", @errors) );
    $response = WWW::Cachet::Response->new( ok => FALSE, message => $self->error );
  }

  return $response;
}

1;
__END__
=head1 TODO

- API Calls that need to be implemented

  /incidents/:incident/updates.*
  /actions.*

- POD/documentation could do with a bit of love - hopefully for now it's enough to get you going

- More/better tests

=head1 BUGS

addSubscriber
  Setting the 'components' key in the request doesn't actually work.
  Probably need to rework the POST request code to send a JSON body rather than form encoded vars.

If you find any more bugs/issues/etc email me at the address below. Alternatively you can submit a
pull request or open an issue at https://github.com/texh/WWW-Cachet

Viva la open sauce


=head1 AUTHOR

Jarrod Linahan <jarrod@linahan.id.au>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Jarrod Linahan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
