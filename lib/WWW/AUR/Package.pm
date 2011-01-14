package WWW::AUR::Package;

use warnings;
use strict;

use File::Basename qw(basename);
use File::Path     qw(make_path);
use File::Spec     qw();
use Carp           qw();

use WWW::AUR::Package::File;
use WWW::AUR::UserAgent;
use WWW::AUR::URI;
use WWW::AUR::RPC;
use WWW::AUR qw( _path_params );

##############################################################################
# CONSTANTS
#-----------------------------------------------------------------------------

my $MAINTAINER_MATCH = qr{ <span [ ] class='f3'>
                           Maintainer: \s+ ( [^<]+ )
                           </span> }xms;

#---CONSTRUCTOR---
sub new
{
    my $class = shift;

    Carp::croak( "You must at least supply a name as argument" ) if @_ == 0;

    my $name   = shift;
    my %params = @_;

    # Load up the info
    my %info;
    if ( ! defined $params{info} ) {
        %info = eval { WWW::AUR::RPC::info( $name ) }
            or Carp::croak( "Failed to find package: $name" );
    }
    else { %info = %{ $params{info} }; }

    my $self = bless { _path_params( @_ ),
                       pkgfile     => "$name.src.tar.gz",
                       info        => \%info,
                      }, $class;

    return $self;
}

sub _def_info_accessor
{
    my ($field) = @_;

    no strict 'refs';
    *{ "WWW::AUR::Package::$field" } = sub {
        my ($self) = @_;
        return $self->{info}{$field} || q{};
    };
}

for ( qw{ id name version desc category locationid url urlpath
          license votes outdated } ) { _def_info_accessor( $_ ); }

#---PUBLIC METHOD---
# Returns a copy of the package info as a hash...
sub info
{
    my ($self) = @_;
    return %{ $self->{info} };
}

#---PRIVATE METHOD---
sub _download_url
{
    my ($self) = @_;

    return pkgfile_uri( $self->name );
}

#---OBJECT METHOD---
sub download_size
{
    my ($self) = @_;

    my $ua   = WWW::AUR::UserAgent->new();
    my $resp = $ua->head( $self->_download_url() );
    
    return undef unless $resp->is_success;
    return $resp->header( 'content-length' );
}

#---OBJECT METHOD---
sub download
{
    my ($self, $usercb) = @_;

    my $pkgurl  = $self->_download_url();
    my $pkgpath = File::Spec->catfile( $self->{dlpath},
                                       $self->{pkgfile} );

    make_path( $self->{dlpath} );

    open my $pkgfile, '>', $pkgpath or die "Failed to open $pkgpath:\n$!";
    binmode $pkgfile;

    my $store_chunk = sub {
        my $chunk = shift;
        print $pkgfile $chunk;
    };

    if ( $usercb ) {
        my $total = $self->download_size();
        my $dled  = 0;

        my $store = $store_chunk;
        $store_chunk = sub {
            my $chunk = shift;
            $dled += length $chunk;
            $usercb->( $dled, $total );
            $store->( $chunk );
        };
    }

    my $ua   = WWW::AUR::UserAgent->new();
    my $resp = $ua->get( $self->_download_url(),
                         ':content_cb' => $store_chunk );
    close $pkgfile or die "close: $!";
    Carp::croak( 'Failed to download package file:' . $resp->status_line )
        unless $resp->is_success;

    $self->{pkgfile_obj} = WWW::AUR::Package::File->new
        ( $pkgpath, _path_params( %$self ));

    return $pkgpath;
}


#---PUBLIC METHOD---
# Purpose: Scrape the package webpage to get the maintainer's name
sub maintainer
{
    my ($self) = @_;

    my $uri  = pkg_uri( ID => $self->id );
    my $ua   = WWW::AUR::UserAgent->new();
    my $resp = $ua->get( $uri );

    Carp::croak sprintf q{Failed to load webpage for the }
        . q{"%s" package:\n%s}, $self->name, $resp->status_line
        unless $resp->is_success;

    my ($username) = $resp->content() =~ /$MAINTAINER_MATCH/xms;
    Carp::croak qq{Failed to scrape package webpage for maintainer}
        unless $username;

    # Orphaned packages don't have a maintainer...
    return undef if $username eq 'None';

    # Propogate parameters to our new Maintainer object...
    require WWW::AUR::Maintainer;
    my %params = _path_params( %$self );
    my $m_obj  = WWW::AUR::Maintainer->new( $username, %params );

    return $m_obj;
}

sub _def_file_wrapper
{
    my ($name) = @_;

    no warnings 'redefine';
    no strict 'refs';
    my $file_method = *{ $WWW::AUR::Package::File::{$name} }{ 'CODE' };
    *{ $name } = sub {
        my $self = shift;
        return undef unless $self->{'pkgfile_obj'};
        my $ret = eval { $file_method->( $self->{'pkgfile_obj'}, @_ ) };
        die if $@;
        return $ret;
    };
}

_def_file_wrapper( $_ ) for qw{ extract src_pkg_path
                                src_dir_path make_src_path build
                                bin_pkg_path };

# Wrap the Package::File methods to call download first if we have to...
sub _def_dl_wrapper
{
    my ($name) = @_;

    no warnings 'redefine';
    no strict   'refs';

    my $oldcode = *{ $name }{ 'CODE' };
    *{ $name } = sub {
        my $self = shift;
        unless ( $self->{'pkgfile_obj'} ) { $self->download(); }
        return $oldcode->( $self, @_ );
    };
}

_def_dl_wrapper( $_ ) for qw/ extract build /;

#---PRIVATE METHOD---
# Purpose: Download the package's PKGBUILD without saving it to a file.
sub _download_pkgbuild
{
    my ($self) = @_;

    my $name         = $self->name;
    my $pkgbuild_uri = pkgbuild_uri( $name );

    my $ua   = WWW::AUR::UserAgent->new();
    my $resp = $ua->get( $pkgbuild_uri );
    
    Carp::croak "Failed to download ${name}'s PKGBUILD: "
        . $resp->status_line() unless $resp->is_success();

    return $resp->content();
}

sub pkgbuild
{
    my ($self) = @_;

    return $self->{pkgfile_obj}->pkgbuild
        if $self->{pkgfile_obj};

    return $self->{pkgbuild_obj}
        if $self->{pkgbuild_obj};

    my $pbtext = $self->_download_pkgbuild;

    return $self->{pkgbuild_obj} = WWW::AUR::PKGBUILD->new( $pbtext );
}

1;
