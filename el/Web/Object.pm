package el::Web::Object;
use strict;
use el::Db;
use GD;
use Data::Dumper;
use Template;

sub new {
  my ($class,$context,$h)=@_;
  $h={} unless $h;
  my $self =  bless {%$h}, $class; # @_в bless не ставить
  $self->{table}||='webobject';
  return $self;
}

sub Init {
  my ($self,$context) = @_;
  $self->{db}=$context->db();
  $self->{context}=$context;
  return 1;
}

sub objects {
  my ($self) = @_;
  return undef unless $self->{db};
  my $list =
    $self->{db}->
      sqlSelectAll("select * from $self->{table}")
      || return {};
  my %h;
  foreach my $r (@$list) {
    $r->{roles}=GetAccessRoles($self->{db},$r->{id});
    next unless checkAccess($r,$self->{context}->user());
    my $pid = $r->{parent_id} || 0;
    $h{$pid}={} unless $h{$pid};
    $h{$r->{id}}={} unless $h{$r->{id}};
    $h{$r->{id}}->{data_}=$r;
    $h{$pid}->{$r->{path}}=$h{$r->{id}};
    $h{$pid}->{$r->{id}}=$h{$r->{id}};
  }
  return $h{0};
}

sub GetTree {
  my ($self,$parent_id) = @_;
  return $self->GetList($parent_id,1);
}

sub GetList {
  my ($self,$parent_id,$tree) = @_;
  my $parent_where = "parent_id is null";
  my @parent_bind;
  if ($parent_id) {
    if ($parent_id=~/\D+/) {
      my $res = $self->{db}->
        sqlSelectOne("select * from $self->{table} where path=?",$parent_id)
          || return undef;
      $parent_id=$res->{id};
    }
    $parent_where = "parent_id=?";
    push @parent_bind, $parent_id;
  }
#  $el::Db::DEBUG=1;
  my $list = $self->{db}->
    sqlSelectAll("select * from $self->{table} where $parent_where order by list_order, id",
                 @parent_bind)
      || return undef;
  my @l;
  foreach my $r (@$list) {
    $self->parseObject($r);
    next unless checkAccess($r,$self->{context}->user());
    $r->{childs}=$self->GetTree($r->{id})
      if $tree;
    push @l,$r;
  }
  return \@l;
}


sub GetAccessRoles {
  my ($db,$object_id)=@_;
  my $roles = $db->
    sqlSelectAll("select * from webobject2roles left join webuser_roles on webuser_roles.id=webobject2roles.role_id where object_id=?",
                 $object_id);
  return {map {$_->{name}=>$_->{id}} @$roles};
}

sub checkAccess {
  my ($object,$user) = @_;
  return 1 if $object->{anon_access};
#  print STDERR "CHECK ACCESS user: $user\n";
  return undef unless $user;
  return 1 if $user->{is_root};
  foreach (keys %{$user->{roles}}) {
    return 1 if exists $object->{roles}->{$_};
  }
  return 0;
}

sub GetByPath {
  my ($self,$path) = @_;
  my $r = $self->{db}->sqlSelectOne("select * from $self->{table} where path=?",$path)
    || return undef;
  return $self->parseObject($r);
}

sub GetByID {
  my ($self,$id) = @_;
  my $r = $self->{db}->sqlSelectOne("select * from $self->{table} where id=?",$id)
    || return undef;
  return $self->parseObject($r);
}

sub GetImages {
  my ($self,$id) = @_;
  return $self->{db}->sqlSelectAll("select * from webobject_image where object_id=?",$id);
}

sub parseObject {
  my ($self,$r) = @_;
  $r->{roles}=GetAccessRoles($self->{db},$r->{id});
  return undef unless checkAccess($r,$self->{context}->user());
  $r->{images}=$self->GetImages($r->{id});

  my $image;
  my %images;
  foreach my $i (@{$r->{images}}) {
    $images{$i->{name}}=$i;
    $r->{image}=$i if $i->{name} eq $r->{image};
  }
  $r->{output}=$r->{text};
  # Иначе фигня на orionet.ru/actions/
#  $r->{output}=~s/\n/<br>/mg;
  #<img >
  $r->{output}=~s{\$images\[(\S+)\]}{<img src=/pic/objects/$r->{id}-$images{$1}->{name} width=$images{$1}->{width} height=$images{$1}->{height}>}mg;
#  $r->{output}=el::Web::View::TT::filter_escape($r->{text});
  return $r;
}

sub processTemplate {
  my ($self,$page,$params,$options) = @_;
  $options={} unless $options;
  $params={} unless $params;
#  die Dumper($options);
  my $r;
  my $tt = Template->
    new(%$options,
        #LOAD_FILTERS=>$self->{filters},
        COMPILE_DIR=>'/tmp/ttc/',
        COMPILE_EXT=>'.ttc',
        INTERPOLATE=>1,
        POST_CHOMP=>1,
        PRE_CHOMP=>1,
        RELATIVE=>1,
        ABSOLUTE=>1,
        TRIM=>1,
        AUTO_RESET=>0,
        OUTPUT=>\$r)
      || die "Template processing init error ",Template->error();
  $tt->process(\$page->{text},
               {page=>$page,
                %$params})
    || die "Web object template processing error ($options->{INCLUDE_PATH}) ",$tt->error();
  $page->{output}=$r;
  return $page->{output};
}

sub Modify {
  my ($self,$data,$id) = @_;
  $data->{modify_user_id}=$self->{context}->user()->{id}
    unless $data->{modify_user_id};
  $data->{modify_time}='now()'
    unless $data->{modify_time};
  $self->{db}->sqlUpdate($self->table(),
                         $data,
                         'id=?',$id);
}

sub Delete {
  my ($self,$id) = @_;
  $self->{db}->
       sqlQuery('delete from webobject_image where object_id=?',
                 $id);
  my $l = $self->{db}->sqlSelectAll("select * from $self->{table} where parent_id=?",$id);
  if ($l) {
  foreach my $o (@$l) {
    $self->Delete($o->{id});
  }
  }
  return $self->{db}->sqlQuery("delete from $self->{table} where id=?",$id);
}

sub Create {
  my ($self,$data) = @_;
  $data->{modify_user_id}=$self->{context}->user()->{id}
    unless $data->{modify_user_id};
  $data->{modify_time}='now()'
    unless $data->{modify_time};
  $self->{db}->sqlBegin();
#  my $random_path;
  unless ($data->{path}) {
#    $random_path=1;
    $data->{path}=el::Web::Session::GenerateKey();
  }
  my $res = $self->{db}->
    sqlInsert($self->table(),
              $data,
              'id');
  $self->{db}->sqlCommit();
  return $res;
}

sub table { $_[0]->{table} }

sub ChangeRolesAccess {
  my ($self,$c,$object_id) = (shift,shift,shift);
 # my @roles = ;
#  $el::Db::DEBUG=1;
  $c->{db}->sqlBegin();
  $c->{db}->sqlQuery('delete from webobject2roles where object_id=?',$object_id);
  my $all_access;
  foreach (@_) {
    if ($_ eq 'all') {
      $all_access = 1;
    } else {
      $c->{db}->
        sqlInsert('webobject2roles',
                  {object_id=>$object_id,
                   role_id=>$_
                  });
    }
  }
  $all_access=$all_access ? 't' : 'f';
  $c->{db}->sqlQuery('update webobject set anon_access=? where id=?',$all_access,$object_id);
  $c->{db}->sqlCommit();
}


# ВЫдает следующий несуществующий путь для объекта

sub getNextPath {
  my ($self,$c) = @_;
  my $res = $c->{db}->sqlSelectOne('select max(id) as max from webobject');
  my $m = $res->{max}+1;
  return "$m.html";
}


#
#
# sub CheckConstraint {
#  my ($self,$data) = @_;
# }
#
# sub FieldsList {
#  my $self = shift;
#  return {path=>'notnull',
# 	 title=>'notnull',
# 	 text=>'notnull'};
# }
#


1;
