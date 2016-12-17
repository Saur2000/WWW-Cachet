package WWW::Cachet::Component;

use constant TRUE  => 1;
use constant FALSE => 0;

use Moo;
extends 'WWW::Cachet::Object';
use Carp qw/ confess /;

has id => (
  is  => 'rw',
  isa => sub {
    confess "'$_[0]' is not an integer!" if $_[0] !~ /^\d+$/;
  }
);

has name => (
  is       => 'rw',
  required => TRUE
);

has description => (
  is       => 'rw',
);

has status => (
  is       => 'rw',
  isa      => sub {
    confess "Invalid component status" unless ($_[0] =~ /^[1-4]$/); 
  },
  required => TRUE
);

has link => (
  is       => 'rw',
);

has order => (
  is       => 'rw',
);

has group_id => (
  is       => 'rw',
  isa => sub {
    confess "'$_[0]' is not an integer!" if $_[0] !~ /^\d+$/;
  }
);

has enabled => (
  is       => 'rw',
  isa      => sub {
    confess "'enabled' should be 1 or 0" unless ($_[0] =~ /^[01]$/);
  },
);

1;
__END__
=head1 NAME

WWW::Cachet::Component - Perl wrapper for Cachet API's component

=head1 SYNOPSIS

  use WWW::Cachet::Component;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WWW::Cachet, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Jarrod Linahan, E<lt>jarrod@linahan.id.au<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Jarrod Linahan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.2 or,
at your option, any later version of Perl 5 you may have available.


=cut