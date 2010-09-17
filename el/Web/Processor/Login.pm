package el::Web::Processor::Login;
use strict;
use el::Web::Processor;
use base qw(el::Web::Processor);

sub new {
  my ($class,$c,$name,$h)=@_;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{name} = $name;
  $h={} unless $h;
  $self->{sites}=$h->{sites} || [$c->{config}->{default_site}];
  $self->
    Register($c,'/login','sys/login',
             [
              '/login _self login',
              '/logout _self logout',
              '/forget _self forget',
              '/sign _self sign'
             ]);
  $self->clone_self();
  return $self;
}

sub ACTION_login {
  my ($self,$c) = @_;
  return $c->redirect($c->{uri}->{referer} || $c->{uri}->{home})
      if $c->user_object()->Login($c);
#  $c->user_object()->Login($c);
  $c->template("$self->{templ_path}/no_login.html");
  return {login=>$c->param('login')};
}

sub ACTION_sign {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/sign.html");
  return undef unless $c->param('ok');
  return undef unless $c->user_object()->Sign($c);
  $c->template("$self->{templ_path}/signed.html");
}

sub ACTION_forget {
  my ($self,$c) = @_;
  die 123;
  $c->template("$self->{templ_path}/forget.html")
}

sub ACTION_logout {
  my ($self,$c) = @_;
  $c->user_object()->Logout($c);
  $c->redirect($c->{uri}->{home});
}

1;
