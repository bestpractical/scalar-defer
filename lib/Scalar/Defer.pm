package Scalar::Defer;
$Scalar::Defer::VERSION = '0.05';

use 5.006;
use strict;
use warnings;
use overload ();
use Exporter::Lite;
use Class::InsideOut qw( private register id );
our @EXPORT = qw( lazy defer force );

private _defer => my %_defer;

BEGIN {
    # Set up overload for the package "0".
    overload::OVERLOAD(
        '0' => fallback => 1, map {
            $_ => sub { &{$_defer{ id $_[0] }} }
        } qw( bool "" 0+ ${} @{} %{} &{} *{} )
    );

    no strict 'refs';
    *{"0::AUTOLOAD"} = sub {
        my $meth = our $AUTOLOAD;
        my $idx = index($meth, '::');
        if ($idx >= 0) {
            $meth = substr($meth, $idx + 2);
        }

        unshift @_, force(shift(@_));
        goto &{$_[0]->can($meth)};
    };

    foreach my $sym (keys %UNIVERSAL::) {
        *{"0::$sym"} = sub {
            unshift @_, force(shift(@_));
            goto &{$_[0]->can($sym)};
        };
    }

    *{"0::DESTROY"} = \&DESTROY;
}

sub defer (&) {
    my $cv = shift;
    my $obj = register( bless \(my $s), __PACKAGE__ );
    $_defer{ id $obj } = $cv;
    bless($obj => 0);
}

sub lazy (&) {
    my $cv = shift;
    my ($value, $forced);
    my $obj = register( bless \(my $s), __PACKAGE__ );
    $_defer{ id $obj } = sub {
        $forced ? $value : scalar (++$forced, $value = &$cv)
    };
    bless($obj => 0);
}

sub force ($) {
    &{$_defer{ id $_[0] or return $_[0]}}
}

1;

__END__

=head1 NAME

Scalar::Defer - Calculate values on demand

=head1 SYNOPSIS

    use Scalar::Defer; # exports 'defer' and 'lazy'

    my ($x, $y);
    my $dv = defer { ++$x };    # a deferred value (not memoized)
    my $lv = lazy { ++$y };     # a lazy value (memoized)

    print "$dv $dv $dv"; # 1 2 3
    print "$lv $lv $lv"; # 1 1 1

    my $forced = force $dv;     # force a normal value out of $dv

    print "$forced $forced $forced"; # 4 4 4

=head1 DESCRIPTION

This module exports two functions, C<defer> and C<lazy>, for building
values that are evaluated on demand.  It also exports a C<force> function
to force evaluation of a deferred value.

=head2 defer {...}

Takes a block or a code reference, and returns a deferred value.
Each time that value is demanded, the block is evaluated again to
yield a fresh result.

=head2 lazy {...}

Like C<defer>, except the value is computed at most once.  Subsequent
evaluation will simply use the cached result.

=head2 force $value

Force evaluation of a deferred value to return a normal value.
If C<$value> was already normal value, then C<force> simply returns it.

=head1 NOTES

Deferred values are not considered objects (C<ref> on them returns C<0>),
although you can still call methods on them, in which case the invocant
is always the forced value.

Unlike the C<tie>-based L<Data::Lazy>, this module operates on I<values>,
not I<variables>.  Therefore, assigning into C<$dv> and C<$lv> above will
simply replace the value, instead of triggering a C<STORE> method call.

Also, thanks to the C<overload>-based implementation, this module is about
2x faster than L<Data::Lazy>.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT (The "MIT" License)

Copyright 2006 by Audrey Tang <cpan@audreyt.org>.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is fur-
nished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FIT-
NESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE X
CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
