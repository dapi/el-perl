package el::Web::Processor::Objects;
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
    Register($c,'/objects','sys/objects',
             [
             '/ _self index',
             '/add _self add',
             '/edit _self edit',
             '/delete _self delete',
             '/show _self show',
             '/image _self image'
             ]);
  $self->clone_self();
  return $self;
}

sub Init {
  my ($self,$context) = @_;
  $self->clear_self();
  $self->{object}=$context->object();
  return $self;
}

sub object {
  my $self = shift;
  return $self->{object};
}

sub Fields {
  my ($self,$c,$action) = @_;
  my $f = $c->Fields(qw(title path text list_order parent_id is_closed show_children));
  $f->{is_closed}=$f->{is_closed} ? 1 : 0
    if exists $f->{is_closed};
  $f->{show_children}=$f->{show_children} ? 1 : 0;
  $f->{parent_id}=undef if exists $f->{parent_id} && !$f->{parent_id};
  $f->{path}=$self->object()->getNextPath($c)
    if exists $f->{path} && !$f->{path};
  return $f;
}



sub ACTION_index {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/index.html");
#  $el::Db::DEBUG=1;
  return $self->object()->GetTree();
}

sub ACTION_show {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/show.html");
  return $self->object()->GetByID($c->param('id'));
}


sub ACTION_image {
  my ($self,$c) = @_;
  my $object_id = $c->param('object_id');
  my $dir="$c->{config}->{root_dir}/pic/objects";
  if ($c->param('load')) {
    my $file =
      $c->UploadFile('/tmp/el',
                     'file')
        || die "Can't upload file";
    my $image = GD::Image->new($file)
      || die "Can't open file $file";
    my ($width,$height) = $image->getBounds();
    my $name = $file;
    $name=~s/.+\///g;
    `mv $file $dir/$object_id-$name`
      && die "Can't move file $file to $dir/$object_id-$name";
    my $res = $c->db()->
      sqlSelectOne('select * from webobject_image where object_id=? and name=?',
                   $object_id,$name);
    if ($res) {
      $c->db()->
        sqlQuery('update webobject_image set width=?, height=? where object_id=? and name=?',
                 $width, $height, $object_id, $name);
    } else {
      $c->db()->
        sqlInsert('webobject_image',
                  {object_id=>$object_id,
                   name=>$name,
                   width=>$width,
                   height=>$height});

    }
  } elsif ($c->param('delete')) {
    my $image=$c->param('image');
    `rm $dir/$object_id-$image`;
    $c->db()->
      sqlQuery('delete from webobject_image where object_id=? and name=?',
               $object_id,$image);
  } elsif ($c->param('make_general')) {
    my $image = $c->param('image');
    $c->db()->
      sqlQuery('update webobject set image=? where id=?',
               $image,$object_id);
  }
  $c->redirect("$c->{uri}->{home}$self->{uri}/edit?id=$object_id");
}


sub ACTION_add {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/edit.html");
  $c->data('parents',$self->object()->GetTree());
#  $el::Db::DEBUG=1;
  el::Web::Processor::Users::SetRolesList($c);
  if ($c->param('ok')) {
    my $id = $self->object()->Create($self->Fields($c,'create'));
    $self->object()->ChangeRolesAccess($c,$id,$c->param('roles'));
    $c->redirect("$c->{uri}->{home}$self->{uri}/");
  } else {
    $c->data('fields',{path=>$self->object()->getNextPath($c)});
  }
  return 1;
}

sub ACTION_delete {
  my ($self,$c) = @_;
  my $id = $c->param('id');

  my $o = $self->object()->GetByID($id);
  die "Can't delete closed object" if $o->{is_closed};
      $c->db()->
        sqlQuery('delete from webobject_image where object_id=?',
                 $id);
  $self->object()->Delete($id);
  return $c->redirect("$c->{uri}->{home}$self->{uri}/");
}

sub ACTION_edit {
  my ($self,$c) = @_;
  $c->template("$self->{templ_path}/edit.html");
  $c->data('parents',$self->object()->GetTree());
  el::Web::Processor::Users::SetRolesList($c);
  my $id = $c->param('id');
  if ($c->param('ok')) {
    $self->object()->Modify($self->Fields($c,'modify'), $id);
    $self->object()->ChangeRolesAccess($c,$id,$c->param('roles'));
    $c->redirect("$c->{uri}->{home}$self->{uri}/");
  } else {
    $c->data('fields',$self->object()->GetByID($id));
  }
  return $c->data('fields');
}


1;
