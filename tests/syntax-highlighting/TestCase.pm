
package TestCase;
use Test;
require 'foo.pl';

local $number = 1;
my $regexp = qr/this/;
my $regexpi = qr/InSensitive/i;
=simplepod
simple Perl POD style comment
=cut
# simple Perl style comment
 2;
3;
$constant = 3;
$single_quoted_string = 'singly quoted string';
$double_quoted_string = "doubly quoted string";
$array = ();
$array2 = (1, , );

sub foo (argument, argument2, argument3,

argument4) {
  if (condition) {
    expression;
  } else if (!condition2) {
    expression2;
    expression3;
  } else {
    if (other && conditions) {
      !expression;
    }
  }
}

sub exception() {
  try {
    throw 1;
  } catch (e) {
    do_something;
  } finally {
    return something_else;
  }
  return not_reached;
}

sub MyClass() {
  this._foo = 0;
}

$array3 = ("a", "big", "bird", "can't" . " fly");

sub reserved_words() {
  try {} catch (e instanceof Exception) {
    var foo = new Bar;
  } finally {
    for each (var i in {});
    do { nothing; } while (false);
    if (!true || !!'' && " " | 3 & 7);
    while (false | true & false) nothing;
    a = [];
    a[3] = 0;
    a.q = RegExp("2");
  }
  null == undefined;
  null !== undefined;
  var z |= 15 ^ 29;
  return null;
}

sub not_reserved_words() {
  tryThis();
  throwThis();
  catchThis();
  finallyThis();
  returnThis();
  varThis();
  constThis();
  newThis();
  voidThis();
  ifThis();
  elseThis();
  elsif;
  instanceofThis();
}

=podcommented
sub exception {
}
=cut

sub nextfunc {
}

=podcommented

exception();
nextfunc();

sub nextfunc {
}
=cut

sub lastfunc {
}
