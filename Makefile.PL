use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'              => 'WWW::Map::UK::Streetmap',
    'VERSION_FROM'      => 'Streetmap.pm', # finds $VERSION
    'PREREQ_PM'         => { LWP::UserAgent                 => 1,
                             Test::More                     => 0 },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Streetmap.pm', # retrieve abstract from module
       AUTHOR     => 'Simon Batistoni <simon@hitherto.net>') : ()),
);
