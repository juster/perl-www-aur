package WWW::AUR::Package;

use warnings;
use strict;

use LWP::UserAgent qw();
use File::Path     qw(make_path);
use File::Spec     qw();
use WWW::AUR       qw();
use Memoize        qw(memoize);
use Carp           qw();

my $AUR_PKGFMT    = "$WWW::AUR::BASEURI/packages/%s/%s.tar.gz";
my $AUR_PBFMT     = "$WWW::AUR::BASEURI/packages/%s/%s/PKGBUILD";

sub new
{
    my $class = shift;

    Carp::croak( "You must at least supply a name as argument" ) if @_ == 0;
    my $name   = shift;
    my %params = @_;

    my %obj;
    if ( ! defined $params{info} ) {
        %obj = eval { WWW::AUR->info( $name ) }
            or Carp::croak( "Failed to find package: $name" );
    }
    else { %obj = %{ $params{info} }; }

    my $base = $params{basepath};
    unless ( ( $params{dlpath} && $params{extpath} && $params{destpath} )
             || $base ) {
        $base = $WWW::AUR::BASEPATH;
    }

    $obj{ dlpath   } = $params{dlpath}   || "$base/src";
    $obj{ extpath  } = $params{extpath}  || "$base/build";
    $obj{ destpath } = $params{destpath} || "$base/cache";
    $obj{ pkgfile  } = "$name.src.tar.gz";
    $obj{ name     } = $name;
    
    bless \%obj, $class;
}

sub info
{
    my ($self) = @_;
    return %{ $self->{info} };
}

sub _download_url
{
    my ($self) = @_;
    return sprintf $AUR_PKGFMT, $self->{name}, $self->{name};
}

sub download_size
{
    my ($self) = @_;

    my $ua   = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp = $ua->head( $self->_download_url() );
    
    return undef unless $resp->is_success;
    return $resp->header( 'content-length' );
}
memoize( 'download_size' );

sub download
{
    my ($self, $usercb) = @_;

    my $pkgurl  = $self->_download_url();
    my $pkgpath = "$self->{dlpath}/$self->{pkgfile}";

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

    my $ua   = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp = $ua->get( $self->_download_url(),
                         ':content_cb' => $store_chunk );

    close $pkgfile or die "close: $!";

    Carp::croak( 'Failed to download package file:' . $resp->status_line )
        unless $resp->is_success;

    $self->{srcpkg_path} = $pkgpath;
    return $pkgpath;
}

sub srcpkg_path
{
    my ($self) = @_;
    return $self->{srcpkg_path};
}

sub extract
{
    my ($self) = @_;

    my $pkgpath = $self->srcpkg_path || $self->download();
    my $destdir = $self->{dlpath};

    make_path( $destdir );

    my $retval = system "bsdtar -zx -f $pkgpath -C $destdir";
    die "failed to extract source packge with bsdtar:\n$!"
        unless $retval == 0;

    my $srcpkg_dir = File::Spec->catdir( $destdir, $self->{name} );
    return $self->{srcpkg_dir} = $srcpkg_dir;
}

sub srcpkg_dir
{
    my ($self) = @_;
    return $self->{srcpkg_dir};
}

1;

__END__
