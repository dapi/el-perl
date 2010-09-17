package el::Web::Processor::Users;
use strict;
use el::Db;
use el::Web::Session;
use base qw(el::Web::Processor);

sub new {
  my ($class,$c,$name,$h)=@_;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->{name} = $name;
  $h={} unless $h;
  $self->{sites}=$h->{sites} || [$c->{config}->{default_site}];
  $self->
    Register($c,'/users','sys/users',
             [
              '/ _self index',
              '/add _self add',
              '/edit _self edit',
              '/delete _self delete',
              '/show _self show'
             ]
            );
  $self->clone_self();
  return $self;
}

sub ACTION_index {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/index.html");
  my $list = $c->db()->sqlSelectAll('select * from webuser where not is_removed order by id');
  foreach my $u (@$list) {
    $u->{roles}=el::Web::User::GetRoles($c,$u->{id});
  }
  return $list;
}

sub Fields {
  my ($self,$c) = @_;
  my $f = $c->Fields(qw(name login));
  $f->{password}=$c->param('password');
  delete $f->{password} unless $f->{password};
  return $f;
}

sub SetRolesList {
  my ($c)= @_;
  $c->{roles}=$c->db()->sqlSelectAll('select * from webuser_roles');
}

sub ParseRoles {
  my $roles = shift;
  return {map {$_=>1} split(',',$roles)};
}

sub LoadUser {
  my ($c,$user_id)=@_;
  my $user = $c->db()->sqlSelectOne('select * from webuser where id=?',$user_id);
  $user->{roles}=el::Web::User::GetRoles($c,$user_id);
  return $user;
}

sub ChangeRoles {
  my ($c,$user_id,$rp) = @_;
  my @roles = $c->param($rp || 'roles');
  $c->{db}->sqlBegin();
  $c->{db}->sqlQuery('delete from webuser2roles where user_id=?',$user_id);
  foreach (@roles) {
    $c->{db}->
      sqlInsert('webuser2roles',
                {user_id=>$user_id,
                 role_id=>$_
                });
  }
  $c->{db}->sqlCommit();
}

sub ACTION_delete {
  my ($self,$c) = @_;
  my $id = $c->param('id');
  $c->redirect("$c->{uri}->{home}$self->{uri}/");
  $c->{db}->sqlQuery('delete from webuser2roles where user_id=?',$id);
  $c->{db}->sqlQuery('update webuser set is_removed=?, login=? where id=?',
                     't',"removed_$id",$id);
}



sub ACTION_edit {
  my ($self,$c) = @_;
  my $id = $c->param('id');
  $c->template("$self->{templ_path}/edit.html");
  SetRolesList($c);
  if ($c->param('ok')) {
    my $f = $self->Fields($c);
    $c->db()->sqlUpdate('webuser', $f, 'id=?', $id);
    ChangeRoles($c,$id);
    $c->redirect("$c->{uri}->{home}$self->{uri}/");
  } else {
    $c->data('fields',LoadUser($c,$id));
  }
  return $c->data('fields');
}

sub ACTION_add {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/edit.html");
#  $el::Db::DEBUG=1;
  SetRolesList($c);
  return 1 unless $c->param('ok');
  my $f = $self->Fields($c);
  $f->{session}="session_$f->{login}".el::Web::Session::GenerateKey(10);
  my $id = $c->db()->sqlInsert('webuser', $f, 'id');
  ChangeRoles($c,$id);
  $c->redirect("$c->{uri}->{home}$self->{uri}/");
  return 1;
}


1;
