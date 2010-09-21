use inc::Module::Install;

name     'WWW-AUR';
all_from 'lib/WWW/AUR.pm';

requires 'Carp'           => 0;
requires 'HTTP::Cookies'  => 0;
requires 'Text::Balanced' => 0;
requires 'File::Path'     => 0;
requires 'File::Spec'     => 0;
requires 'Cwd'            => 0;
requires 'LWP::Simple'    => 0;
requires 'URI'            => 0;

clean_files 't/tmp';

WriteAll;
