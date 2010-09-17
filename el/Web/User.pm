package el::Web::User;
use strict;
use Storable;
use el::Web::Form;
use el::Web::NoAccess;
use el::Web::Session;
use base qw(el::Base);
use Data::Serializer;
use Data::Dumper;

sub new {
  my ($class,$context,$h)=@_;
  my $self =  bless {%$h}, $class; # @_в bless не ставить
  $self->{user_table}='webuser';
  # print STDERR "user new\n";
  $self->{ser}=Data::Serializer->new(compress=>0,
                                     portable=>1
                                    );
  $self->clone_self();
  return $self;
}

sub IsLoginExists {
  my ($self,$context,$login) = @_;
  return $context->{db}->
    sqlSelectOne("select * from $self->{user_table} where lower(login)=?",
                 lc($login));
}

sub Sign {
  my ($self,$context,$f) = @_;
  unless ($f) {
    $f = el::Web::Form->GetForm($context,
                                {login=>{type=>'text',
                                         obligated=>1,
                                         unique=>sub {
                                           my $login = shift;
#                                           print STDERR "Check login: $login\n";
                                           return !$self->IsLoginExists($context,$login);
                                         }},
                                 password=>{type=>'password',
                                            obligated=>1},
                                 email=>{type=>'email',
                                         obligated=>1},
                                 name=>{type=>'text',
                                        obligated=>1}})
      || return undef;
  }

  $f->{session}="ses_$f->{login}_".el::Web::Session::GenerateKey(10);
  $f->{sign_ip}=$context->remote_ip();
  $f->{last_ip}=$context->remote_ip();
  $f->{is_logged}='t';
#  $f->{session_data}=undef;

  my $id =
    $context->{db}->
      sqlInsert($self->{user_table},$f,'id');
  return undef unless $id;
  $f->{id}=$id;
  $self->do_login($context,$f,"ses_$f->{login}");
  return $f;
}

sub Init {
  my ($self,$c,$s) = @_;
  $self->clear_self();
#  print STDERR "user clear\n";
  $self->{is_logged}=0;
  $self->{data}={};
  $self->{session_data}={};
  $self->loginBySSID($c,
                        $c->param('ssid') || $c->session_object()->ssid());
}

sub Get {
  my ($self,$key) = @_;
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub loginBySSID {
  my ($self,$context,$ssid) = @_;
#  print STDERR "Login by session '$ssid'\n";
  return undef
    unless $ssid;
  return undef
    unless
      $self->{data}=$context->{db}->
        sqlSelectOne("select * from $self->{user_table} where session=? and is_logged and not is_removed",
                     $ssid);
  $context->{db}->
    sqlQuery("update $self->{user_table} set lasttime=CURRENT_TIMESTAMP, last_ip=? where id=?",
             $context->remote_ip(),
             $self->{data}->{id});

  $self->do_login($context,$self->{data},$ssid);
}

sub Logout {
  my ($self,$context) = @_;
  return undef
    unless $self->IsLogged();
  $context->{db}->
    sqlQuery(qq(update $self->{user_table} set is_logged='f' where id=?),
             $self->{data}->{id});
  $self->{is_logged}=0;
  $self->{data}=undef;
}

sub Login {
  my ($self,$context) = @_;
  my $login = $context->param('login');
  my $password = $context->param('password');

  my $u=$context->{db}->
    sqlSelectOne("select * from $self->{user_table} where login=? and not is_removed",
              $login) || return undef;
  unless ($u) {
    $context->data('login_result','no_user');
    return undef;
  }
  unless ($u->{password} eq $password) {
    $context->data('login_result','bad_password');
    return undef;
  }

#  $el::Db::DEBUG=1;
  $u->{ssid} = el::Web::Session::GenerateKey();
  $context->{db}->
    sqlQuery(qq(update $self->{user_table}
            set lasttime=CURRENT_TIMESTAMP, sessiontime=CURRENT_TIMESTAMP,
            session=?, last_ip=?, is_logged='t' where id=?),
             $u->{ssid},
             $context->remote_ip(),
             $u->{id});

#  print STDERR "Login by login '$login' $u->{ssid}\n";

  $self->do_login($context,$u,$u->{ssid});
}

sub GetRoles {
  my ($context,$user_id)=@_;
#  $el::Db::DEBUG=1;
  my $roles = $context->{db}->
    sqlSelectAll("select webuser_roles.* from webuser2roles left join webuser_roles on webuser_roles.id=webuser2roles.role_id where user_id=?",
                 $user_id);
  return {map {$_->{name}=>$_->{id}} @$roles};
}

sub HasRoles {
  my $self = shift;
  foreach (@_) {
    return 0
      unless exists $self->{data}->{roles}->{$_};
  }
  return @_ ? 1 : 0;
}

sub CheckAccess {
  my $self = shift;
  throw el::Web::NoAccess("No access ".join(',',@_),2,$self)
    unless $self->HasRoles(@_);
}

sub do_login {
  my ($self,$context,$user,$ssid) = @_;
  $self->{is_logged}=1;
  $self->{data}=$user;

  $self->{session_data}=$self->{ser}->deserialize($user->{session_data}) || {};
  $self->{session_data}={} unless ref($self->{session_data})=~/HASH/;
#  $el::Db::DEBUG=1;
#  print STDERR "SESSION_DATA restore ", Dumper($self->{session_data}), "\n";

  $user->{roles}=GetRoles($context,$user->{id});
  $context->session_object()->
    ssid($ssid);
#  die "$ssid";

  $self->JoinSessions($context);

  $context->session_object()->
      SetStoreObject($self);
#  print STDERR "do_login: $ssid\n";
}

sub JoinSessions {
  my ($self,$context) = @_;
  my $old_data = $context->{session_object}->{data};
  $self->{session_data}->{basket}=$old_data->{basket}
    if $old_data && $old_data->{basket};
  $context->{session_object}->{data}=$self->{session_data};
  return $context->session_object()->StoreData($context,{});
}

sub StoreData {
  my ($self,$context,$data) = @_;
  return $context->session_object()->StoreData($context,$data)
    unless $self->IsLogged();
#  print STDERR "session_data", Dumper($data),"\n";
  $context->{db}->
    sqlQuery(qq(update $self->{user_table}
            set session_data=? where id=?),
             $self->{ser}->serialize($data),
             $self->{data}->{id});
}

sub session {
  my $self = shift;
  return $self->{session_data};
}

sub IsLogged {
  my $self = shift;
  return $self->{is_logged};
}

1;
