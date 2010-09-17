package el::Web::Page;
use strict;


sub new {
  my $class = shift;
  my $self =  bless {}, $class; # @_в bless не ставить
  $self->init(@_);
  return $self;
}


sub Load {
 my ($self,$id) = @_;
}

sub Modify {
 my ($self,$data,$id) = @_;
}

sub Delete {
 my ($self,$id) = @_;
}

sub Create {
 my ($self,$data) = @_;
}

sub LoadByPath {
 my ($self,$path) = @_;
}

sub MoveToFolder {
 my ($self,$folder_id) = @_;
}


sub TableName {
 my $self = shift;
}


sub CheckConstraint {
 my ($self,$data) = @_;
}

sub FieldsList {
 my $self = shift;
 return {path=>'notnull',
	 title=>'notnull',
	 text=>'notnull'};
}

sub GetFields {
 my ($self,$c) = @_;
}

sub Action_Create {
 my ($self,$c) = @_;
 my $f = $self->GetFields($c,'create') || return undef;
 return $self->{db}->sqlInsert($self->TableName(),$f,'id');
}

sub Action_Modify {
 my ($self,$c) = @_;
 my $id = $c->GetParam('id') || die "No param ID";
 my $f = $self->GetFields($c,'modify') || return undef;
 return $self->{db}->sqlUpdate($self->TableName(),$f,"id=?",[$id]);
}



1;
