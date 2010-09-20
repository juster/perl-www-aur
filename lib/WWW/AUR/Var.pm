package WWW::AUR::Var;

use warnings;
use strict;

use parent qw(Exporter);

our @EXPORT = qw($VERSION $BASEPATH $BASEURI $USERAGENT);

our $VERSION   = '0.01';
our $BASEPATH  = '/tmp/WWW-AUR';
our $BASEURI   = 'http://aur.archlinux.org';
our $USERAGENT = "WWW::AUR/v$VERSION";

1;
