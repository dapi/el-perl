package ${SYSTEM}::Home;
use strict;
use base qw(el::Web::Processor);
#use elefant::Handler;

sub ACTION_index {
  my ($self,$c) = @_;
  $c->template('home.html');
  return {};
}

1;
