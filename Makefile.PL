use strict;
use inc::Module::Install;

name        'Data-Defer';
license     'MIT';
all_from    'lib/Data/Defer.pm';

requires    'Class::InsideOut';
requires    'Exporter::Lite';

include_deps 'ok';
include_deps 'Test::More';

sign; WriteAll;
