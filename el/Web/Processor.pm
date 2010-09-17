package el::Web::Processor;
use strict;
use el::Web::NoAccess;
use base qw(el::Base);
use vars qw($VERSION);

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
  my ($class,$c,$name,$h)=@_;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{name} = $name;
  $h={} unless $h;
  $self->{sites}=$h->{sites} || [$c->{config}->{default_site}];
  $self->clone_self();
  return $self;
}

sub Init {
  my $self = shift;
  $self->clear_self();
  return $self;
}

sub preaction {
  my ($self,$c,$action) = @_;
  $self->CheckAccess($c,$action);
}

sub CheckAccess {
  my ($self,$c,$action) = @_;
  return 1 unless $c->{access_roles} && @{$c->{access_roles}};
  return 1 if $c->{access_roles}->[0] eq '*';
  throw el::Web::NoAccess("user it not logged",1)
    unless $c->user();
  return $c->user_object()->
    CheckAccess(@{$c->{access_roles}});
}

sub go {
  my ($self,$c,$action) = @_;
  $self->preaction($c,$action);
  my $ref = $self->can("ACTION_$action") || die "No such action: $action in processor $self";
  return $ref->($self,$c);
}

sub execute_action {
  my ($self,$c,$action) = @_;
  $action = $c->{action} unless $action;
  $self->preaction($c,$action);
  my $ref = $self->can("ACTION_$action") || die "No such action: '$action' in processor $self";
  return $ref->($self,$c);
}

sub execute_lookup {
  my ($self,$c,$lookup,$subpath) = @_;

  my $ref = $self->can("LOOKUP_$lookup") || die "No such lookup: $lookup in processor $self";
  return &$ref($self,$c,$subpath);
}

sub LOOKUP_default {
  my ($self,$c,$path) = @_;
  return $c->
    _lookup("/$path",
            $c->{config}->{processor_pages}->{$self->{name}},
            $self);
}

sub Register {
  my ($self,$context,$uri,$templ_path,$pages) = @_;
  my $name = $self->{name};

  $context->{config}->{templ_path}->{$name}=$templ_path
    unless $context->{config}->{templ_path}->{$name};
  $self->{templ_path}=$context->{config}->{templ_path}->{$name};

  $context->{config}->{uri}->{$name}=$uri
    unless $context->{config}->{uri}->{$name};
  $self->{uri}=$context->{config}->{uri}->{$name};

  foreach my $site (@{$self->{sites}}) {
    unshift @{$context->{config}->{pages}->{$site}->{page}},
      "$self->{uri}/* $name:default";
  }

  # Не понятно зачем это, config->processors уже нигде не используется
  #  $context->{config}->{processors}->{$name}='el::Web::Processor::Login';

  $context->{config}->{processor_pages}->{$name}={}
    unless $context->{config}->{processor_pages}->{$name};

  $context->{config}->{processor_pages}->
    {$name}->{page}=$pages;

}

1;
