package WWW::Map::UK::Streetmap;

use 5.006;
use strict;
use warnings;

use Carp;
use LWP::UserAgent;

use vars qw ($VERSION);

$VERSION = '0.02';

=head1 NAME

WWW::Map::UK::Streetmap - Retrieve map urls and location data from
www.streetmap.co.uk

=head1 SYNOPSIS

  use WWW::Map::UK::Streetmap;

  # Spawn a new streetmap object

  my $streetmap = WWW::Map::UK::Streetmap->new();

  # get location by postcode

  my %pc_location = $streetmap->get_location(postcode => 'W2 4BB');

  # get location by OS grid reference

  my %os_location = $streetmap->get_location(os_x => '525688',
                                             os_y => '181069');

  # get location by WGS84 latitude and longitude (World Geodetic  # System)

  my %wgs_location = $streetmap->get_location(wgs_lat  => '51.514572',
                                              wgs_long => '-0.190067');

  # get location by latitude and longitude

  my %ll_location = $streetmap->get_location(lat  => 'N51:30:52',
                                             long => 'W0:11:24');

  # get location by Landranger grid

  my %lr_location = $streetmap->get_location(lr_grid => 'TQ256810');

  # get location data by streetmap url

  my $url_location = $streetmap->get_location(url =>
                                    "http://www.streetmap.co.uk[...]");

  # (all of the above returned hashes will contain the same
  # information, give or take differences in accuracy between
  # co-ordinate systems)

  # use hash data

  print $pc_location{postcode}."\n";
  print $pc_location{os_x}.", ".$pc_location{os_y}."\n";
  print $pc_location{wgs_lat}.", ".$pc_location{wgs_long}."\n";
  print $pc_location{lat}.", ".$pc_location{long}."\n";
  print $pc_location{lr_grid}."\n";
  print $pc_location{url}."\n";

  # get a map URL from location data

  my $map_url = $streetmap->get_map(postcode => 'W2 4BB');

  # (you get the idea... you can also get a map using any of the other
  # location data used by get_location() )

  # work out a distance "as the crow flies" between 2 locations

  # and yes, once again, it uses the same location data identifiers as
  # other methods. Consistency is a great thing, innit?

  my $distance = $streetmap->crow_flies({postcode => 'W2 4BB'},
                                        {postcode => 'SW1 2LA'});

  my $miles = $streetmap->miles($distance);

=head1 DESCRIPTION

This module can take varied location data, specifically Latitude and
Longitude references, OS X and Y co-ordinates, Landranger location
codes, postcodes or existing Streetmap URLs, and return the
complementary location data, or a URL pointing to a map on the
L<http://www.streetmap.co.uk> website.

=head1 METHODS

=over 4

=item new

Creates a new instance of the class.  Name value pairs may be passed
which will have the same effect as calling the method of that name
with the value supplied.

=cut

sub new {
    my $class = shift;
    my $this = bless {}, $class;

    # call the set methods
    my %args = @_;
    foreach my $method (keys %args)
    {
      if ($this->can($method))
      {
        $this->$method($args{$method})
      }
      else
      {
        croak "Invalid argument '$method'";
      }
    }

    return $this;
}

=item get_location

This will return a full hash of location data for any given point,
provided it is given at least one of: OS x and y co-ordinates, WGS84
latitude and longitude, traditional latitude and longitude, Landranger
Grid reference or postcode.

If get_location is handed more than one piece of locational data, it
will pick one in order of priority as listed.

The keys for location data which get_location accepts (and will return
in its hash) are:

os_x, os_y, wgs_lat, wgs_long, lat, long, lr_grid, postcode, url

The conversion routine *should* be able to cope with any URL taken
from the www.streetmap.co.uk site, but is absolutely guaranteed to
work with the "link to this map" URLs that they present on each
page. It is also a URL of this form that will be returned by the
routine.

=cut

sub get_location {
  my ($self, %args) = @_;

  # variables we'll be using imminently
  my ($location_name,$convert_type, %results);

  # test that any "paired" data we have (like lat/long) has both
  # halves present

  &_check_paired(%args);

  my %url = &_set_url_elements(%args);

  # fetch the page from streetmap

  my $data_url = "http://www.streetmap.co.uk/streetmap.dll?GridConvert?name=$url{location}&type=$url{convert}";

  my $ua = new LWP::UserAgent;
  $ua->agent("WWW::Map::UK::Streetmap/$VERSION ". $ua->agent);

           my $req = new HTTP::Request GET => $data_url;

  my $res = $ua->request($req);

  croak "Request to streetmap failed" unless $res->is_success;

  my $streetmap_page = $res->content;

  # match page contents to retrieve location data

  $streetmap_page =~ m!OS X\s*</strong>\s*</td>\s*<td(.+?)>(.+?)</td>!;
  ($results{os_x} = $2) =~ s!\s!!g;
  $streetmap_page =~ m!OS Y\s*</strong>\s*</td>\s*<td(.*?)>(.+?)</td>!;
  ($results{os_y} = $2) =~ s!\s!!g;
  $streetmap_page =~ m!Post Code\s*</strong>\s*</td>\s*<td\s*(.*?)>(.+?)</td>!;
  ($results{postcode} = $2) =~ s!\s*$!!;
  $streetmap_page =~ m!Lat\s*</strong>\s*\(WGS84\)\s*</td>\s*<td\s*(.*?)>(.+?)\s*\(\s*(.+?)\s*\)\s*</td>!;
  ($results{lat} = $2) =~ s!\s!!g;
  ($results{wgs_lat} = $3) =~ s!\s!!g;
  $streetmap_page =~ m!Long\s*</strong>\s*\(WGS84\)\s*</td>\s*<td(.*?)>(.+?)\s*\(\s*(.+?)\s*\)\s*</td>!;
  ($results{long} = $2) =~ s!\s!!g;
  ($results{wgs_long} = $3) =~ s!\s!!g;
  $streetmap_page =~ m!LR\s*</strong>\s*</td>\s*<td(.*?)>(.+?)</td>!;
  ($results{lr_grid} = $2) =~ s!\s!!g;

  $results{url} = $self->get_map_url(%results);

  return %results;
}

=item get_map_url

This will return a URL which points to a streetmap of any given
point. It takes the same location data arguments as C<get_location()>,
and uses them in the same order of priority.

Most of the time, there is little point in using this, since you get a
URL from get_location anyway. But it's accessible for completeness'
sake.

=cut

sub get_map_url {
  my ($self, %args) = @_;

  # check and initialise our data

  &_check_paired(%args);

  my %url = &_set_url_elements(%args);

  # format a URL. Since URLs are based on OS grids, if we don't have that data available,
  # we need to fetch it using get_location()

  if (!$args{os_x}) {
    my %location = $self->get_location(%args);
    return "http://www.streetmap.co.uk/streetmap.dll?G2M?X=$location{os_x}&Y=$location{os_y}&A=Y&Z=1";
  } else {
    return "http://www.streetmap.co.uk/streetmap.dll?G2M?X=$args{os_x}&Y=$args{os_y}&A=Y&Z=1";
  }
}

=item crow_flies

Given 2 sets of location data, crow_flies will work out the kilometre
distance "as the crow flies" between them.

Because it takes 2 sets of location data, you'll need to bung it the
data in 2 anonymous hashes, or references to pre-defined hashes,
unlike the other methods.

=cut

sub crow_flies {
  my ($self, $loc1, $loc2) = @_;

  &_check_paired(%$loc1);
  &_check_paired(%$loc2);

  if (!$$loc1{os_x}) { %$loc1 = $self->get_location(%$loc1); }

  if (!$$loc2{os_x}) { %$loc2 = $self->get_location(%$loc2); }

  my $distance_x = $$loc1{os_x} - $$loc2{os_x};
  if ($distance_x < 0) { $distance_x *= -1; }
  my $distance_y = $$loc1{os_y} - $$loc2{os_y};
  if ($distance_y < 0) { $distance_y *= -1; }

  my $distance = sqrt(($distance_x*$distance_x)+($distance_y*$distance_y));

  return sprintf "%.04f",$distance/1000;
}

=item miles

This is just a quick utility sub to convert kilometre distances to
(UK) miles, if you don't want the kilometres returned by crow_flie()

=cut

sub miles {
  my ($self, $distance) = @_;

  my $miles = $distance * 0.621;

  return $miles;
}

=back

=cut

# _________________________INTERNAL METHODS___________________________

# _check_paired - checks that incoming items are paired where they
# need to be (namely, co-ordinate location data)

sub _check_paired {
  my %args = @_;

  if (($args{os_x} || $args{os_y}) && !($args{os_x} && $args{os_y})) {
    croak "OS grid reference missing one co-ordinate";
  }
  if (($args{wgs_lat} || $args{wgs_long}) &&
    !($args{wgs_lat} && $args{wgs_long})) {
    croak "WGS84 lat/long pair missing one co-ordinate";
  }
  if (($args{lat} || $args{long}) && !($args{lat} && $args{long})) {
    croak "lat/long pair missing one co-ordinate";
  }
  # if we got here, we're fine and can return
}

# set_url_elements - work out what data we have, and accordingly set
# up elements which can go into the grid conversion url

sub _set_url_elements {
  my %args = @_;

  my ($location_name, $convert_type);

  # set up the necessary parts of the conversion URL, according to
  # available data
  if ($args{os_x}) {
    $location_name = "$args{os_x},$args{os_y}";
    $convert_type  = "OSGrid";
  } elsif ($args{wgs_lat}) {
    $location_name = "$args{wgs_lat},$args{wgs_long}";
    $convert_type = "LatLong";
  } elsif ($args{lat}) {
    $location_name = "$args{lat},$args{long}";
    $convert_type="LatLong";
  } elsif ($args{lr_grid}) {
    $location_name = $args{lr_grid};
    $convert_type = "LRGrid";
  } elsif ($args{postcode}) {
    $location_name = $args{postcode};
    $convert_type="Postcode";
  } elsif ($args{url}) {
    $args{url} =~ m!X=(\d*)\&!i;
    my $x = $1;
    $args{url} =~ m!Y=(\d*)\&!i;
    my $y = $1;
    $location_name = "$x,$y";
    $convert_type = "OSGrid";
  } else {
    croak "No workable location data given to get_location";
  }

  # if we're here, we have something to return...

  my %return = (location => $location_name,
                convert  => $convert_type);

  return %return;
}

=head2 EXPORT

None. OO Interface only.

=head2 REQUIREMENTS

LWP::UserAgent

=head1 TODO

Caching. The module will be able to cache locations its seen before to
a text file, or possibly a database (mysql initially, I expect). This
will be vastly superior for relatively busy applications. We may even
set up a central location caching server (which you'll specify as your
cache location when you instantiate an object), which will take the
load off Streetmap.

Possibly add methods to work with streetnames, picking up the list of
possible matches in the case of multiples, and dumping them back to
the user. This requires more thought to give a sane programmable
interface than I'm prepared to give version 0.1.

=head1 AUTHOR

Simon Batistoni E<lt>simon@hitherto.netE<gt>

=head1 COPYRIGHT

This software is copyright(c) 2002 Simon Batistoni. It is free
software and can be used under the same terms as perl, i.e. either the
GNU Public Licence or the Artistic License.

=head1 SEE ALSO

L<perl>, L<http://www.streetmap.co.uk>.

=cut

1;











