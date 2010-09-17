package el::Web::Form;
use strict;
use Email::Valid;
use base qw(el::Base
            Exporter);


use vars qw(
	    @EXPORT
           );

@EXPORT = qw(NewForm
             NewCGIForm);

sub NewForm {
  return el::Web::Form->new(@_);
}

sub new {
  my ($class,$name,$fields)=@_;
  my $self =  bless {name=>$name}, $class; # @_в bless не ставить
#  $self->{fields_list}=$fields_list || [];

  $self->{fields}=$fields;
  $self->{errors}=[];
  $self->{bad_fields}={};
  return $self;
}

sub Field {
  my ($self,$f) = @_;
  return $self->{fields}->{$f} if exists $self->{fields}->{$f};
}

sub Fields {
  my $self = shift;
  return $self->{fields};
}

sub FieldsList {
  my $self = shift;
  return $self->{fields_list};
}

sub Validate {
  my ($self,$rules,@to_validate) = @_;
  $rules=[$rules] unless ref($rules)=~/ARRAY/;
  my @e;
  foreach my $f (@to_validate) {
    foreach my $r (@$rules) {
      my $ref = $self->can("validate_$r") || die "No such validator: $r";
      push @e, $self->AddError($f,$r)
        unless &$ref($self,$f,$self->{fields}->{$f},$r,$self->{fields});
    }
  }
  return !@e;
}

sub validate_notempty {
    my ($self,$field,$value,$rule,$params) = @_;
    return $value ne '';
}

sub validate_login {
    my ($self,$field,$login) = @_;
    return $login ne '' && $login!~/[^a-z_0-9\.\-]+/i;
}

sub validate_mobile {
    my ($self,$field,$mobile) = @_;
    return length($mobile)>=11 && length($mobile)<=20;
}

sub validate_password {
    my ($self,$field,$value,$rule,$params) = @_;
    return $value ne $params->{$field.'2'};
}

sub validate_email {
    my ($self,$field,$value,$rule,$params) = @_;
    return Email::Valid->address($value);
}



sub Errors {
  my $self  = shift;
  return @{$self->{errors}} ? $self->{errors} : undef;
}

sub AddError {
  my ($self,$field,$rule) = @_;

  push @{$self->{errors}},{field=>$field,
                           rule=>$rule};
  $self->{bad_fields}->{$field}=$rule;
  #  $self->{bad_fields}->{$field}={}
    #unless $self->{bad_fields}->{$field};
  #$self->{bad_fields}->{$field}->{$rule}=1;
  #$self->{bad_fields}->{$field}->{list_}.=",$rule";
}



1;
