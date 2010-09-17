package el::Web::Context;
use strict;
use Config::General;
use CGI;
use CGI::Cookie;
use Error qw(:try);
use el::Db;
use el::Config;
use base qw(el::Base);

#( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;

=pod

r - ApacheRequest

uri
 home =
 path = путь после home
 current = текущей запрошеный uri
 query = все, что после ?
 referer

site - имя сайта из конфига

config - конфиг

user - пользователь

user_object - модуль пользователя
session - модуль сессии
view - модуль view

ssid - ключ сессии

login_result - результат логина (no_user или bad_password)

data - данные текущей сессии

page

processor
action
access_roles
other
subpath - остатки путя, не вошедшие в action

=cut


sub new {
  my ($class,$h)=@_;
  my $self =  bless {}, $class; # @_в bless не ставить

  my $conf = new Config::General(
                                 -ConfigFile      => $h->{config_file},
                                 -UseApacheInclude => 1,
                                 -IncludeRelative => 1,
                                 -IncludeGlob => 1,
                                 #                                 -AutoTrue => 1,
                                 -InterPolateVars => 1);
  $self->{config}={$conf->getall()};


  $self->{db} = el::Db->
    new($self->{config}->{database}) || die "Can't init database $self->{config}->{database}"
      if $self->{config}->{database};

  $self->{object}=
    $h->{object}->{class}->
      new($self,
          $h->{object})
        if $h->{object};
  $self->{view}=
    $h->{view}->{class}->new($self)
      if $h->{view};
  $self->{session_object}=
    $h->{session}->{class}->
      new($self,$h->{session})
        if $h->{session};

#   $self->{noaccess_object}=
#     $h->{noaccess}->{class}->
#       new($self,$h->{noaccess})
#         if $h->{noaccess};

  $self->{user_object}=
    $h->{user}->{class}->
      new($self,$h->{user})
        if $h->{user};

  $self->{processors}={};
  if ($h->{processors}) {
    foreach my $name (keys %{$h->{processors}}) {
      my $p = $h->{processors}->{$name};
      $p={class=>$p} unless ref($p);
      $self->{processors}->{$name}=
        $p->{class}->new($self,$name,$p);
    }
  }

  $self->clone_self();

  return $self;
}

sub Init {
  my ($self,$r,$uri) = @_;
  setConfig($self->{config});
  $self->clear_self();
  $self->{uri}=$uri;
  $self->{out_cookies}=undef;

  $self->{in_cookies}=undef;
  $self->{db}->sqlConnect() || die "Can't connect to database"
    if $self->{db};
  $self->{object}->Init($self)
    if $self->{object};

  if ($r) {
    $self->{cgi}=CGI->new;
    $self->{r}=$r;
    $self->{remote_ip}=
      $self->{r}->headers_in()->{'X-Forwarded-For'} ||
        $self->{r}->connection()->remote_ip();
  }
  $self->{view}->Init($self)
    if $self->{view};
  $self->{session_object}->Init($self) if $self->{session_object};
  $self->{user_object}->Init($self) if $self->{user_object};
  $self->{no_access_object}->Init($self) if $self->{no_access_object};
  $self->{data}={};
  $self->postinit();
  return 1;
}

sub postinit {}; # Для будущих переопределений

sub Deinit {
  my ($self,$r,$uri) = @_;
  $self->{db}->sqlDisconnect() || die "Can't connect to database"
    if $self->{db};
  return 1;
}


sub remote_ip { $_[0]->{remote_ip}; }

sub InitProcessor {
  my ($self,$p) = @_;
  my $po = $self->{processors}->{$p} || die "No such processor: $p";
  return $po->Init($self);
}

sub db {
  my $self = shift;
  return $self->{db};
}

sub data {
  my ($self,$key,$value) = @_;
  return $self->{data}->{$key}=$value if @_>=3;
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub redirect {
  my ($c,$l) = @_;
  $c->{view}->{file}='';
  $c->{view}->{code}=Apache2::Const::REDIRECT;
  return $c->{view}->{location}=$l;
}

sub template {
  my ($s,$t) = @_;
  return $s->{view}->{file} unless $t;
  return $s->{view}->{file}=$t;
}

sub Fields {
  my $self = shift;
  my %f;
  my %p = map {$_=>1} $self->cgi()->param();
  foreach (@_) {
    $f{$_}=$self->cgi()->param($_)
      if exists $p{$_};
  }
  return \%f;
}

sub params {
  my $self = shift;
  my %f;
  map {$f{$_}=$self->cgi()->param($_)} $self->cgi()->param();
  return \%f;
}

sub param {
  my $self = shift;
  return @_ ? $self->cgi()->param(@_) : $self->cgi()->param();
}
sub cookies {
  my ($self,$key) = @_;
  $self->{in_cookies}={CGI::Cookie->fetch($self->{r})}
    unless $self->{in_cookies};
  return $key ? $self->{in_cookies}->{$key} : $self->{in_cookies};
}

sub addCookie {
  my ($self,$cookie) = @_;
  $self->{out_cookies}=[] unless $self->{out_cookies};
#  print STDERR "push cookie $cookie, size ",scalar @{$self->{out_cookies}},"\n";
  push @{$self->{out_cookies}},$cookie;
  return $cookie;
}

sub outCookies {
  my $self = shift;
#  print STDERR "set cookies\n";
  return $self->{out_cookies};
}


sub object { $_[0]->{object} }
sub cgi { $_[0]->{cgi} }
sub config { $_[0]->{config} }

sub user_object {
  my $self = shift;
  return $self->{user_object};
}

sub user {
  my $self = shift;
  return $self->user_object()->Get()
    if $self->user_object() &&
      $self->user_object()->IsLogged();
  return undef;
}

sub session_object {
  my $self = shift;
  return $self->{session_object};
}

sub session {
  my $self = shift;
  return undef unless $self->{session_object};
  return $self->{session_object}->Data(@_);
}

sub view { $_[0]->{view} }

sub lookupSite {
  my ($self,$uri)=@_;
  my $c = $self->{config};
  foreach my $site (keys %{$c->{sites}}) {
    my $v = $c->{sites}->{$site};
    my $a = ref($v) ? $v : [$v];
    foreach my $v (@$a) {
      print STDERR "lookupSite $v <?> $_\n";
      if ($uri=~s/^([a-z]+):\/\/$v//e) {
        my $h = $1 || 'http';
        $self->{uri}->{home}="$h://$v";
        $uri="/$uri" unless $uri=~/^\//;  # Иначе при использовании дома сайта с путем тут стоит пусто
        $self->{uri}->{path}=$uri;
        return $self->{site}=$site;
      }
    }
  }
  return undef;
}

=pod

В результате работы лукапа возникает следующее:

страница не найдена

найдена страница, запускается процессор и действие

найдена страница, управление передается в lookup процессора

=cut

sub Lookup {
  my ($self,$uri) = @_;
  my $site = $self->lookupSite($uri) || return undef;
  return undef unless $site;

  return $self->
    _lookup($self->{uri}->{path},
            $self->{config}->{pages}->{$self->{site}});
}

sub _lookup {
  my ($self,$look_path,$p,$pself)=@_;
  my $pages = $p->{page};
  return undef unless $pages;
  $pages=[$pages] unless ref($pages);
#  print STDERR "access: $p->{access}\n";
  $self->{access_roles}=[split(',',$p->{access})]
    if $p->{access};
  foreach my $page (@$pages) {
#    print STDERR "_lookup: $look_path - $page\n";
    my $p = $look_path;
    my ($path,$pl,$ar)=split(/\s+/,$page);
    my ($action,$access_roles)=split(':',$ar);
    my ($processor,$lookup)=split(':',$pl);
    if ($path eq $p) {
      $self->{processor} = $processor eq '_self' ? $pself : $self->InitProcessor($processor);
      die 'no _self here' unless $self->{processor};
      $self->{action}=$action;
      $self->{access_roles}=[split(',',$access_roles)]
        if $access_roles;
      return 1 unless $lookup;
      return $self->{processor}->execute_lookup($self,$lookup);
    } elsif ($path=~s/\*$// && $p=~s/^$path//e) {
#      print STDERR "lookup: $path $p\n";
      $self->{processor} = $processor eq '_self' ? $pself : $self->InitProcessor($processor);
      die 'no _self here' unless $self->{processor};
      $self->{uri}->{subpath}=$p;
      $self->{action}=$action;
      $self->{access_roles}=[split(',',$access_roles)]
        if $access_roles;
      return 1 unless $lookup;
      return $self->{processor}->execute_lookup($self,$lookup,$p);
    }
  }
  return undef;
}

sub View {
  my ($self,$res) = @_;
  return $self->{view}->
    process($self,$res);
}

# sub ThrowNoAccess {
#   my ($self,$id,$text) = @_;
#   $self->{noaccess_object}->new($id,$text,$self->user());
#   #Error::throw
# }

sub Execute {
  my $self = shift;
  my $res =  $self->{processor}->execute_action($self);
  $self->{session_object}->SaveSession($self)
    if $self->{session_object};
#   $self->{user_object}->SaveSession($self)
#     if $self->{user_object};
  return $res;
}

sub UploadFile {
  my ($context,$dir, $file) = @_;
  $file = $context->cgi()->param($file);
  return undef unless $file;
  my $newfile = $file;
  $newfile=~s/^.*[\/\\]//g; $newfile=~s/\.\.//;  #    $newfile=~s/[^a-z_0-9\-.]/_/ig;
  $newfile=~s/\s/_/g;
  $newfile=~s/\.(.+)$/.\L$1\E/; # lower case extenstion
  unless (-d $dir) {
    mkdir($dir) || die "Can't make dir $dir";
  }
  open(W, "> $dir/$newfile") || fatal("Can't open file $dir/$newfile to write");
  while (<$file>) { print W $_; }
  close(W) || die "Can't close file $dir/$newfile";
  return "$dir/$newfile";
}



1;
