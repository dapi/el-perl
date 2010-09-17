package el::Web::Rating;
use strict;
use Email::Valid;
use el::Db;
use base qw(el::Base
            Exporter);


use vars qw(
	    @EXPORT
           );

@EXPORT = qw(NewRating);

sub NewRating {
  return el::Web::Rating->new(@_);
}

sub new {
  my ($class,$h)=@_;
  my $self =  bless {%$h}, $class; # @_в bless не ставить
  return $self;
}

sub Rate {
  my ($self,$user_id,$item_id,$rating) = @_;
  db()->sqlBegin();
  db()->sqlQuery("select * from $self->{item_table} where id=? for update",$item_id);
  my $r = db()->sqlSelectOne("select * from $self->{rate_table} where $self->{rate_table_item_id}=? and user_id=?",
                             $item_id,$user_id);
  my $res =
    db()->
      sqlSelectOne("select sum(rating) as rating, count(*) as count from $self->{rate_table} where $self->{rate_table_item_id}=?",
                   $item_id);
  $res={} unless $res;
  
  if ($r) {
    $self->{total_rating}=$res->{rating};
    $self->{rating}=$res->{rating}/$res->{count};
    $self->{raters}=$res->{count};
  } else {

    my $r = $res->{rating}+$rating;
    my $c = $res->{count}+1;
    db()->sqlQuery("insert into $self->{rate_table} values (?,?,?)",
                   $user_id,
                 $item_id,
                   $rating);
    db()->sqlQuery("update $self->{item_table} set rating_total=?, rating=?, raters=? where id=?",
                   $r,
                   $r/$c,
                 $c,
                 $item_id);
    $self->{total_rating}=$r;
    $self->{rating}=$r/$c;
    $self->{raters}=$c;
    
  }
  db()->sqlCommit();
}

1;
