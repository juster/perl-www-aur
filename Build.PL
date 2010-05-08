use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::AUR',
    license             => 'perl',
    dist_author         => q{Justin Davis <juster at cpan dot org>},
    dist_version_from   => 'lib/WWW/AUR.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'WWW-AUR-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
