package el::Web::NoAccess;
use strict;
use Data::Dumper;
use dpl::Log;
use Exporter;
use Error;
use Carp;
use base qw(Error);

# 0 - пользовательское
# 1 - пользователь не зареген
# 2 - у пользователя нет соответсвующего доступа

sub new {
  my ($self,$text,$value,$user) = @_;
  local $Error::Depth = $Error::Depth + 1;
  $value=0 unless $value;
  $text='no access' unless $text;
  return $self->SUPER::new(-text=>$text,-value=>$value,-user=>$user);
}

sub stringify {
  my $self = shift;
  return "$self->{-text}";
}

sub Init {}

sub ShowPage {
  my ($self,$context) = @_;
  $context->template("sys/noaccess/noaccess.html");
  return $context->{view}->
    process($context,$self);
}

1;
