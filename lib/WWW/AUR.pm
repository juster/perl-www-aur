package WWW::AUR;

use warnings;
use strict;

use Carp qw();

use WWW::AUR::URI;
use WWW::AUR::Var;
use WWW::AUR::RPC;

our $VERSION = '0.01';

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
    return map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %params );
    } @$found_ref;
}

sub _def_wrapper_method
{
    my ($name, $class) = @_;

    no strict 'refs';
    *{ "WWW::AUR::$name" } = sub {
        my $self        = shift;
        my %path_params = path_params( %$self );

        eval "require $class";
        return eval { $class->new( @_, %path_params ) };
    };
}

_def_wrapper_method( 'find'       => 'WWW::AUR::Package'    );
_def_wrapper_method( 'maintainer' => 'WWW::AUR::Maintainer' );
_def_wrapper_method( 'packages'   => 'WWW::AUR::Iterator'   );
_def_wrapper_method( 'login'      => 'WWW::AUR::Login'      );

1;

__END__

=head1 NAME

WWW::AUR - API for the Archlinux User Repository website.

=head1 SYNOPSIS

  use WWW::AUR;
  my $aur = WWW::AUR->new( basepath => '/tmp/aurtmp' );
  my $pkg = $aur->find( 'perl-www-aur' );
  
  # download_size() can check the file size without downloading...
  printf "Preparing to download source package file (%d bytes).\n",
      $pkg->download_size;
  
  $pkg->download;
  printf "Downloaded pkgfile to %s.\n", $pkg->src_pkg_path;
  
  $pkg->extract;  # calls download() if you didn't
  printf "Extracted pkgfile to %s.\n", $pkg->src_dir_path;
  
  $pkg->build;    # calls extract()  if you didn't
  printf "Built binary pkgfile and saved to %s.\n", $pkg->bin_pkg_path;
  
  my $who = $pkg->maintainer();
  printf "%s is maintained by %s.\n", $pkg->{name}, $who->name;
  
  print "As well as the following packages:\n";
  for my $otherpkg ( $who->packages ) {
      printf " - %s\n", $otherpkg->name;
  }
  
  my $login = $aur->login( 'myname', 'mypassword' )
      or die "Failed to login as myname, what a shock";
  
  $login->vote( 'my-favorite-package' );
  $login->disown( 'i-hate-this-package' );
  $login->upload( '../a-new-package-file.src.pkg.tar.gz' );
  
  print "Iterating through ALL packages...\n";
  my $iter = $aur->packages;
  while ( my $pkgobj = $iter->next ) {
      print "$pkgobj->{name} -- $pkgobj->{version}\n";
  }

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
