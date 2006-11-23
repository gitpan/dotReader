use Test::More tests=>3;

BEGIN {use_ok('dtRdr::User')};
BEGIN {use_ok('dtRdr::Config')};

my $user = dtRdr::User->new(getlogin());
isa_ok($user, 'dtRdr::User');

# TODO add more tests?
