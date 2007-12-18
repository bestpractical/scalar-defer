package Scalar::Defer;

use 5.006;
use strict;
use warnings;

BEGIN {
    our $VERSION = '0.12';
    our @EXPORT  = qw( lazy defer force );
}

use Exporter::Lite;
use Class::InsideOut qw( private register id );
use constant FALSE_PACKAGE => '0';
use constant DEFER_PACKAGE => '0';

BEGIN {
    my %_defer;

    sub defer (&) {
        my $cv = shift;
        my $obj = register( bless(\(my $id) => __PACKAGE__) );
        $_defer{ $id = id $obj } = $cv;
        bless($obj => DEFER_PACKAGE);
    }

    sub lazy (&) {
        my $cv = shift;
        my ($value, $forced);
        my $obj = register( bless(\(my $id) => __PACKAGE__) );
        $_defer{ $id = id $obj } = sub {
            $forced ? $value : scalar(++$forced, $value = &$cv)
        };
        bless($obj => DEFER_PACKAGE);
    }

    sub DEMOLISH {
        delete $_defer{ id shift };
    }

    use constant SUB_FORCE => sub ($) {
        no warnings 'uninitialized';
        &{
            $_defer{ id $_[0] } ||= $_defer{do {
                #
                # The memory address was dislocated.  Fortunately, its original
                # refaddr is saved directly inside the scalar referent slot.
                #
                # So we remove the overload by blessing into UNIVERSAL, get the
                # original refaddr back, and register it with ||= above to avoid
                # doing the same thing next time. (Afterwards we rebless it back.)
                # 
                # This of course assumes that nobody overloads ${} for UNIVERSAL
                # (which will naturally break all objects using scalar-ref layout);
                # if someone does, that someone is more crazy than we are and should
                # be able to handle the consequences.
                #
                my $self = $_[0];
                ref($self) eq DEFER_PACKAGE or return $self;

                bless($self => 'UNIVERSAL');
                my $id = $$self;
                bless($self => DEFER_PACKAGE);
                $id;
            }} || die("Cannot locate thunk for memory address: ".id($_[0]))
        };
    };

    *force = SUB_FORCE();
}

BEGIN {
    package Scalar::Defer::Deferred;
    use overload (
        fallback => 1, map {
            $_ => Scalar::Defer::SUB_FORCE(),
        } qw( bool "" 0+ ${} @{} %{} &{} *{} )
    );

    sub AUTOLOAD {
        my $meth = our $AUTOLOAD;
        my $idx  = index($meth, '::');

        if ($idx >= 0) {
            $meth = substr($meth, $idx + 2);
        }

        unshift @_, Scalar::Defer::SUB_FORCE()->(shift(@_));
        goto &{$_[0]->can($meth)};
    };

    {
        no strict 'refs';
        no warnings 'redefine';

        foreach my $sym (keys %UNIVERSAL::) {
            *{$sym} = sub {
                unshift @_, Scalar::Defer::SUB_FORCE()->(shift(@_));
                goto &{$_[0]->can($sym)};
            };
        }

        *DESTROY = \&Scalar::Defer::DESTROY;
        *DESTROY = \&Scalar::Defer::DEMOLISH;
    }
}

BEGIN {
    no strict 'refs';
    @{FALSE_PACKAGE().'::ISA'} = ('Scalar::Defer::Deferred');
}

1;

__END__

=head1 NAME

Scalar::Defer - Lazy evaluation in Perl

=head1 SYNOPSIS

    use Scalar::Defer; # exports 'defer', 'lazy' and 'force'

    my ($x, $y);
    my $dv = defer { ++$x };    # a deferred value (not memoized)
    my $lv = lazy { ++$y };     # a lazy value (memoized)

    print "$dv $dv $dv"; # 1 2 3
    print "$lv $lv $lv"; # 1 1 1

    my $forced = force $dv;     # force a normal value out of $dv

    print "$forced $forced $forced"; # 4 4 4

=head1 DESCRIPTION

This module exports two functions, C<defer> and C<lazy>, for constructing
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
not I<variables>.  Therefore, assigning anothe value into C<$dv> and C<$lv>
above will simply replace the value, instead of triggering a C<STORE> method
call.

Similarily, assigning C<$dv> or C<$dv> into another variable will not trigger
a C<FETCH> method, but simply propagates the deferred value over without
evaluationg.  This makes it much faster than a C<tie>-based implementation
-- even under the worst case scenario, where it's always immediately forced
after creation, this module is still twice as fast than L<Data::Lazy>.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2006, 2007 by Audrey Tang <cpan@audreyt.org>.

This software is released under the MIT license cited below.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut
