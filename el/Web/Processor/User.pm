package el::Web::Processor::User;
use strict;
use el::Web::Processor;
use base qw(el::Web::Processor);
#use elefant::Handler;

sub ACTION_login {
  my ($self,$c) = @_;
  return $c->redirect('/')
      if $c->user_object()->Login($c);
#  $c->user_object()->Login($c);
  $c->template('no_login.html');
  return {login=>$c->param('login')};
}

sub ACTION_sign {
  my ($self,$c) = @_;
  $c->template('sign.html');
  return undef unless $c->param('ok');
  return undef unless $c->user_object()->Sign($c);
  $c->template('signed.html');
}

sub ACTION_forget {
  my ($self,$c) = @_;
  die 123;
  $c->template('forget.html')
}

sub ACTION_logout {
  my ($self,$c) = @_;
  $c->user_object()->Logout($c);
  $c->redirect('/');
}


1;
