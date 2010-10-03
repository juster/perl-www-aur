package WWW::AUR::Login;

use warnings;
use strict;

use HTTP::Cookies  qw();
use Carp           qw();

use WWW::AUR::UserAgent;
use WWW::AUR::Var;
use WWW::AUR::URI;

use parent qw(WWW::AUR::Maintainer);

my $UPLOADURI      = "${BASEURI}/pkgsubmit.php";
my $COOKIE_NAME    = 'AURSID';
my $BAD_LOGIN_MSG  = 'Bad username or password.';
my $PKG_EXISTS_MSG = ( 'You are not allowed to overwrite the '
                       . '<b>.*?</b> package.' );
my $PKG_EXISTS_ERR = 'You tried to submit a package you do not own';

my $PKGOUTPUT_MATCH = qr{ <p [ ] class="pkgoutput"> ( [^<]+ ) </p> }xms;

sub new
{
    my $class = shift;

    Carp::croak 'You must supply a name and password as argument'
        unless @_ >= 2;
    my ($name, $password) = @_;

    my $ua   = WWW::AUR::UserAgent->new( agent      => $USERAGENT,
                                         cookie_jar => HTTP::Cookies->new() );
    my $resp = $ua->post( $BASEURI,
                          [ user   => $name,
                            passwd => $password ]);

    Carp::croak 'Failed to login to AUR: bad username or password'
        if $resp->content =~ /$BAD_LOGIN_MSG/;

    Carp::croak 'Failed to login to AUR: ' . $resp->status_line
        if ! $resp->is_success && $resp->code != 302;

    my $self = $class->SUPER::new( $name );
    $self->{password}  = $password;
    $self->{useragent} = $ua;
    return $self;
}

my %_PKG_ACTIONS = map { ( lc $_ => "do_$_" ) }
    qw{ Adopt Disown Vote UnVote Notify UnNotify Flag UnFlag };

sub _do_pkg_action
{
    my ($self, $act, $pkg, @params) = @_;

    my $action = $_PKG_ACTIONS{ $act }
        or Carp::croak "$act is not a valid action for a package";

    my $id   = _pkgid( $pkg );
    my $ua   = $self->{useragent};
    my $resp = $ua->post( pkg_uri( ID => $id ),
                          [ "IDs[$id]" => 1, 'ID' => $id,
                            $action    => 1, @params ] );

    Carp::croak 'Failed to send package action: ' . $resp->status_line
        if ! $resp->is_success;

    my ($pkgoutput) = $resp->content =~ /$PKGOUTPUT_MATCH/;
    Carp::croak 'Failed to parse package action response'
        unless $pkgoutput;

    return $pkgoutput;
}

#---HELPER FUNCTION---
sub _pkgid
{
    my $pkg = shift;

    if ( ! ref $pkg ) {
        return $pkg if $pkg =~ /\A\d+\z/;

        require WWW::AUR::Package;
        my $pkgobj = WWW::AUR::Package->new( $pkg );
        return $pkgobj->id;
    }

    Carp::croak 'You must provide a package name, id, or object'
        unless eval { $pkg->isa( 'WWW::AUR::Package' ) };

    return $pkg->id;
}

sub _def_action_method
{
    my ($name, $goodmsg) = @_;
    
    my $method = sub {
        my ($self, $pkg) = @_;
        my $txt = $self->_do_pkg_action( $name => $pkg );
        Carp::croak qq{Failed to perform the $name action on package "$pkg"}
            unless $txt =~ /\A$goodmsg/;
        return $txt;
    };

    no strict 'refs';
    *{ "WWW::AUR::Login::$name" } = $method;

    return;
}

my %_ACTIONS = ( 'adopt'    => 'The selected packages have been adopted.',
                 'disown'   => 'The selected packages have been disowned.',

                 'vote'     => ( 'Your votes have been cast for the selected '
                                 . 'packages.' ),
                 'unvote'   => ( 'Your votes have been removed from the '
                                 . 'selected packages.' ),

                 'notify'   => ( 'You have been added to the comment '
                                 . 'notification list for' ),
                 'unnotify' => ( 'You have been removed from the comment '
                                 . 'notification ist for' ),

                 'flag'     => ( 'The selected packages have been flagged '
                                 . 'out-of-date.' ),
                 'unflag'   => 'The selected packages have been unflagged.',
                );

while ( my ($name, $goodmsg) = each %_ACTIONS ) {
    _def_action_method( $name, $goodmsg );
}

sub upload
{
    my ($self, $pkgfile_path, $catname) = @_;

    Carp::croak "Given file path ($pkgfile_path) does not exist"
        unless -f $pkgfile_path;

    my $catidx = category_index( $catname );
    my $ua     = $self->{useragent};
    my $resp   = $ua->post( $UPLOADURI,
                            'Content-Type' => 'form-data',
                            'Content'      =>
                            [ category  => $catidx,
                              submit    => 'Upload',
                              pkgsubmit => 1,
                              pfile     => [ $pkgfile_path ],
                             ] );

    Carp::croak $PKG_EXISTS_ERR if $resp->content =~ /$PKG_EXISTS_MSG/;

    return;
}

# Create a nifty alias, to match the "My Packages" AUR link...
*my_packages = \&WWW::AUR::Maintainer::packages;

1;

__END__

=head1 NAME

WWW::AUR::Login - Login to the AUR and manage packages, vote, etc.

=head1 SYNOPSIS

  my $login = $aurobj->login( 'whoami', 'password' )
      or die 'failed to login as whoami';
  
  # or ...
  
  my $login = eval { WWW::AUR::Login->( 'whoami', 'password' ) };
  die 'failed to login as whoami' if $@;
  
  # You can use package names for actions...
  $login->adopt( 'my-new-package');
  $login->disown( 'not-my-problem' );
  
  # Or package IDs for actions...
  $login->vote( 12353 );
  $login->unvote( 12353 );

  # Or package objects for actions...
  $login->notify( WWW::AUR::Package->new( 'interesting-package' ));
  $login->unnotify( WWW::AUR::Package->new( 'boring-package' ));
  
  # Flagging packages out of date...
  $login->flag( 'out-of-date-package' );
  $login->unflag( 'up-to-date-package' );
  
  # Upload a new package file...
  $login->upload( '/path/to/package-file.src.tar.gz' );
  
  # Use the inherited WWW::AUR::Maintainer accessors.
  my $name     = $login->name;
  my @packages = $login->packages;

=head1 DESCRIPTION

This module provides an interface for the AUR package maintainer to
perform I<almost> any action they could perform on the
website. Commenting has not yet been implemented.

B<WWW::AUR::Login> is a sub-class of L<WWW::AUR::Maintainer>.

=head1 CONSTRUCTOR

  $OBJ = WWW::AUR::Login->new( $USERNAME, $PASSWORD )

=over 4

=item Parameters

=over 4

=item C<$USERNAME>

The AUR user name to login as.

=item C<$PASSWORD>

The password needed to login as the specified user.

=back

=item Errors

The following errors are thrown with C<die> if we were unable to login
to the AUR.

=over 4

=item Failed to login to AUR: bad username or password

=item Failed to login to AUR: I<< <LWP error> >>

If LWP failed to retrieve the page, an HTTP status code and short
message is inserted after "Failed to login to AUR:".

=back

=back

=head1 SEE ALSO

L<WWW::AUR>

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
