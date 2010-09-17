package el::SOAP::Error;
use strict;
use base qw(Error);

sub new {
  my $self  = shift;
  local $Error::Depth = $Error::Depth + 1;
  return $self->SUPER::new(@_);
}

package el::SOAP::Error::AccessDenied;
use strict;
use base qw(el::SOAP::Error);


1;
