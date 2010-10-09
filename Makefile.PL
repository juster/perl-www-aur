use inc::Module::Install;

name         'WWW-AUR';
version_from 'lib/WWW/AUR.pm';
author_from  'lib/WWW/AUR.pod';
license      'perl';
repository   'http://github.com/juster/perl-www-aur';

requires 'Archive::Tar'   => 0;
requires 'Carp'           => 0;
requires 'Cwd'            => 0;
requires 'HTTP::Cookies'  => 0;
requires 'JSON'           => 0;
requires 'LWP::UserAgent' => 0;
requires 'parent'         => 0;
requires 'File::Path'     => '2.06';
requires 'File::Spec'     => 0;
requires 'Text::Balanced' => 0;
requires 'URI'            => 0;

clean_files 't/tmp';

WriteAll;
