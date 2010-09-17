require 5.004;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);
ExtUtils::Manifest::mkmanifest;
my $version=1;
my $revision=`svnversion -n .`;
$revision=~s/\:/\./g;
#my $CONFIG_DIR='/usr/local/etc';

unlink 'MANIFEST.bak' if -f 'MANIFEST.bak';
unlink 'Makefile.old' if -f 'Makefile.old';


WriteMakefile(
	      NAME	   => 'el',
              VERSION      => "$version.$revision",
	      AUTHOR       => 'Danil Pismenny <danil@orionet.ru>',
	      ABSTRACT     => 'Easy Library',
	      PMLIBDIRS    => [ 'el' ],
	      PREREQ_PM    => {
                               'DBI'           => 1.20,
			      },

	      dist => {COMPRESS=>'bzip2', SUFFIX=>'bz2'},
	      clean => {FILES=>'*.bz2*'}
	     );
