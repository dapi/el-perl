package el::Config;
use strict;
use vars qw(@ISA
	    @EXPORT
            $CONFIG
	    $VERSION
	   );
@ISA = qw(Exporter);

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;

@EXPORT = qw(config
             setConfig);


sub setConfig {
  $CONFIG=shift;
}

sub config {

  return $_[0] ? $CONFIG->{$_[0]} : $CONFIG;
}

1;
