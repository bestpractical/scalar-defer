use Test::More tests => 5;
use ok 'Data::Defer';

my ($x, $y);
my $d = defer { ++$x };
my $l = lazy { ++$y };

is($d, $l, "1 == 1");
is($d, 2, "lazy is now 2");
is($l, 1, "but thunk stays at 1");
isnt($d, $l, "3 != 1");
