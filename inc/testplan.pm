package main; # because Test::More needs caller
# yeah, we should test::builder::whatever or something

require Test::More;

=head1 Usage

It is a switch you can flip.  The first argument is true or false.  If
it is true, your number of tests is the second argument.

  use inc::testplan(1, 50);

  use inc::testplan(0, 50);

=cut

sub inc::testplan::import {
  my $who = shift;
  my ($planned, $tests) = @_;
  Test::More->import(($planned ? (tests => $tests) : ('no_plan')));
}
# vim:ts=2:sw=2:et:sta
