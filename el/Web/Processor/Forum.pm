package el::Web::Processor::Forum;
use strict;
use el::Web::Processor;
use el::Web::Form;
use base qw(el::Web::Processor);
#use elefant::Handler;

sub LOOKUP_topic {
  my ($self,$c,$path) = @_;
  return undef unless $path=~/(\d+)\.html/;
  return $self->{topic}=$self->LoadTopic($c,$1);
}

sub LoadTopic {
  my ($self,$c,$id) = @_;
  my $topic = $c->db()->
    sqlSelectOne('select topic.*, webuser.name as author from topic left join webuser on topic.user_id=webuser.id where topic.id=?',$id);
  return undef unless $topic;
  $topic->{comments}=$self->GetCommentsList($c,$id);
  return $topic;
}

sub GetCommentsList {
  my ($self,$c,$tid) = @_;
  return $c->db()->
    sqlSelectAll('select webuser.login as login, webuser.name as name, comment.* from comment left join webuser on comment.user_id=webuser.id where topic_id=? ',$tid);
}

sub ACTION_add_topic {
  my ($self,$c) = @_;
  my $f = el::Web::Form->
    GetForm($c,
            {subject=>{type=>'text',
                       obligated=>1},
             text=>{type=>'text',
                    obligated=>1}});
  return $self->go($c,'index')
    unless $f;
  $f->{ip}=$c->remote_ip();
  $f->{user_id}=$c->user()->{id};
  my $id = $c->db()->sqlInsert("topic",$f,'id');
  $c->redirect("$c->{uri}->{home}/forum/topics/$id.html");
}

sub ACTION_show_topic {
  my ($self,$c) = @_;
  $c->template('forum/topic.html');
  return $self->{topic};
}

sub ACTION_add_comment {
  my ($self,$c) = @_;
  my $tid=$c->param('tid');
  my $text = $c->param('text');
  $self->CreateComment($c,$tid,$text)
    if $text;
  $c->redirect("$c->{uri}->{home}/forum/topics/$tid.html");
}

sub ACTION_del_comment {
  my ($self,$c) = @_;
  my $id = $c->param('id');
  my $com = $c->db()->
    sqlSelectOne('select * from comment where id=?',$id);
  die "No such comment to delete $id" unless $com;
  $c->db()->sqlQuery('delete from comment where id=?',$id);
  $c->redirect("$c->{uri}->{home}/forum/topics/$com->{topic_id}.html");
}

sub ACTION_del_topic {
  my ($self,$c) = @_;
  my $id = $c->param('id');
  my $t = $c->db()->
    sqlSelectOne('select * from topic where id=?',$id);
  die "No such topic to delete $id" unless $t;
  $c->db()->sqlQuery('delete from topic where id=?',$id);
  $c->redirect("$c->{uri}->{home}/forum/");
}


sub CreateComment {
  my ($self,$c,$tid,$text) = @_;
  my $f = {text=>$text};
#  $el::Db::DEBUG=1;
  $f->{ip}=$c->remote_ip();
  $f->{user_id}=$c->user()->{id};
  $f->{topic_id}=$tid;
  return $c->db()->sqlInsert("comment",$f,'id');
}

sub ACTION_index {
  my ($self,$c) = @_;
  $c->template('forum/index.html');
  return $self->ListTopics($c);
}

sub ListTopics {
  my ($self,$c) = @_;
  $c->db()->
    sqlSelectAll(qq(select topic.*, webuser.login as login, webuser.name as name
                    from topic
                    left join webuser on topic.user_id=webuser.id
                    order by topic.timestamp));
}

1;
