use Test::More tests => 5;
use ok 'Data::Thunk';

my ($x, $y);
my $l = lazy { ++$x };
my $t = thunk { ++$y };

is($l, $t, "1 == 1");
is($l, 2, "lazy is now 2");
is($t, 1, "but thunk stays at 1");
isnt($l, $t, "3 != 1");
