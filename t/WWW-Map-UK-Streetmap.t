#!perl -w

use strict;

# note - we're not going to test get_url, because it's really just a
# wrapper for get_location. If that's working, so it get_url.

use Test::More tests => 15;

require_ok('WWW::Map::UK::Streetmap');

my $streetmap = WWW::Map::UK::Streetmap->new();
isa_ok($streetmap, 'WWW::Map::UK::Streetmap');

# at the writing of these tests, this is the data returned for the
# postcode W2 4BB.

my %expected_loc_data = 
      (lat      => "N51:30:52",
       long     => "W0:11:24",
       lr_grid  => "TQ256810",
       os_x     => "525688",
       os_y     => "181069",
       postcode => "W2 4BB",
       url => "http://www.streetmap.co.uk/streetmap.dll?G2M?X=525688&Y=181069&A=Y&Z=1",
       wgs_lat  => "51.514572",
       wgs_long => "-0.190067");

# check that we can fetch

ok( my %return = $streetmap->get_location(postcode => "W2 4BB"), 
    'fetch location data');

# check that we got the right data back

foreach my $data_key (sort keys %expected_loc_data) {
  ok( $expected_loc_data{$data_key} eq $return{$data_key},
      "check the returned $data_key");
}

# check crow_flies

ok ( my $distance_km = $streetmap->crow_flies(\%expected_loc_data,
                                              {postcode => "E1W 3TJ"}),
     'check crow_flies()' );

ok ( $distance_km = 9.5316, 'check returned distance');

# check km -> miles

ok ( $streetmap->miles(9.5316) == 5.9191236, 'check mile conversion'); 

