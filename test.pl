# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use WWW::Map::UK::Streetmap;
ok(1); # If we made it this far, we're ok.

#########################

# Tests to come, once I find a test framework I actually like. I know,
# I know. This is version 0.01, so shoot me.

