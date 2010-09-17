package el::Web::Processor::Roles;
use strict;
use el::Db;
use base qw(el::Web::Processor);

sub new {
  my ($class,$c,$name,$h)=@_;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{name} = $name;
  $h={} unless $h;
  $self->{sites}=$h->{sites} || [$c->{config}->{default_site}];
  $self->
    Register($c,'/roles','sys/roles',
             [
              '/ _self index',
              '/add _self add',
              '/edit _self edit',
              '/delete _self delete'
             ]
            );
  $self->clone_self();
  return $self;
}

sub ACTION_index {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/index.html");
  return $c->db()->sqlSelectAll('select * from webuser_roles');
}


sub ACTION_edit {
  my ($self,$c) = @_;
  my $id = $c->param('id');
  $c->template("$self->{templ_path}/edit.html");
  if ($c->param('ok')) {
    $c->db()->sqlUpdate('webuser_roles',
                        $c->Fields(qw(name title)),
                        'id=?',$id);
    $c->redirect("$c->{uri}->{home}$self->{uri}/");
  } else {
    $c->data('fields',$c->db()->sqlSelectOne('select * from webuser_roles where id=?',$id));
  }
  return $c->data('fields');
}

sub ACTION_add {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/edit.html");
#  $el::Db::DEBUG=1;
  if ($c->param('ok')) {
    my $id =
      $c->db()->sqlInsert('webuser_roles',
                          $c->Fields(qw(name title)),
                          'id');
    $c->redirect("$c->{uri}->{home}$self->{uri}/");
  }
  return 1;
}


1;
