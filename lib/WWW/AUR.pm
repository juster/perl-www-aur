package WWW::AUR;

use warnings;
use strict;

use LWP::Simple qw();
use JSON        qw();
use Carp        qw();

use WWW::AUR::URI;
use WWW::AUR::Var;
use WWW::AUR::RPC;

our $VERSION   = $VERSION;

sub new
{
    my $class  = shift;
    my %params = @_;
    $params{ basepath } ||= $BASEPATH;

    return bless \%params, $class
}

sub search
{
    my ($self, $query) = @_;
    my $found_ref = WWW::AUR::RPC::search( $query );

    require WWW::AUR::Package;
    my %params = path_params( %$self );
    return [ map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %params );
    } @$found_ref ];
}

sub _def_wrapper_method
{
    my ($name, $class, $param_count) = @_;

    no strict 'refs';
    *{ "WWW::AUR::$name" } = sub {
        my $self        = shift;
        my %path_params = path_params( %$self );

        eval "require $class";
        return eval { $class->new( @_, %path_params ) };
    };
}

_def_wrapper_method( 'find'       => 'WWW::AUR::Package',    1 );
_def_wrapper_method( 'maintainer' => 'WWW::AUR::Maintainer', 1 );
_def_wrapper_method( 'packages'   => 'WWW::AUR::Iterator',   0 );
_def_wrapper_method( 'login'      => 'WWW::AUR::Login',      2 );

1;

__END__

=head1 NAME

WWW::AUR - API for the Archlinux User Repository website.

=head1 SYNOPSIS

  use WWW::AUR;
  my $aur = WWW::AUR->new( basepath => '/tmp/aurtmp' );

=head1 DESCRIPTION

This module provides an interface for the straight-forward AUR user
as well as an AUR author, or package maintainer.

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-aur at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-AUR>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

Read the manual first.  Send me an email if you still need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
