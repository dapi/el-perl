package el::Web::Session;
use strict;
use Digest::MD5;
use Data::Serializer;
use Data::Dumper;
use base qw(el::Base);

sub new {
  my ($class,$context,$h)=@_;
  my $self =  bless {%$h}, $class; # @_в bless не ставить
  $self->{ssid_name}||='sid';
  $self->{data_name}||='sdata';
  $self->{expires}||='+120d';
  $self->{data}={};
  $self->{ssid}=undef;
  $self->{ser}=Data::Serializer->new(compress=>0,
                                     portable=>1
                                 );

  return $self;
}

sub ssid {
  my ($self,$new) = @_;
  return $new ? $self->{ssid}=$new : $self->{ssid};
}

sub Init {
  my ($self,$context) = @_;
  $self->{store_object}=$self;
  my $c = $context->cookies($self->{ssid_name});
  $self->ssid($c ? $c->value() : undef);
  $self->{store_object}->RestoreData($context);
  return $self;
}

sub RestoreData {
  my ($self,$context) = @_;
  my $c = $context->cookies($self->{data_name});
  return $self->{data}=undef  unless $c;
  $self->{data}=$self->{ser}->deserialize($c->value());
#  print STDERR "SESSION: Restore data ",Dumper($self->{data}),"\n";
  return $self->{data};
}

sub SetStoreObject {
  my ($self,$new_obj) = @_;
  $self->{store_object}=$new_obj;
}

sub StoreData {
  my ($self,$context,$data) = @_;

  # Почему то на моем компе $self->{ser} не работает и вызывае: Can't
  # locate object method "serialize" via package "Data::Serializer::"
  # at /usr/lib/perl5/site_perl/5.8.8/Data/Serializer.pm line 565. 
  
  my $s=Data::Serializer->new(compress=>0,
                              portable=>1
                          );
  $context->addCookie(
                      CGI::Cookie->new(-name => $self->{data_name},
                                       -value => $s->serialize($data),
                                       -expires => $self->{expires},
                                      )
                     );
}


sub GetBasket {
  my $self = shift;
  return $self->{data}->{basket};
}

sub ClearBasket {
  my $self = shift;
  return $self->{data}->{basket}=undef;
}

sub AddToBasket {
  my ($self,$item) = @_;
  $self->{data}={} unless ref($self->{data})=~/HASH/;
  $self->{data}->{basket}=[] unless $self->{data}->{basket};
  my $found=0;
  foreach (@{$self->{data}->{basket}}) {
    if ($_->{id}==$item->{id}) {
      $_->{count}+=1;
      $found=1;
      last;
    }
  }
  push @{$self->{data}->{basket}},{%$item,count=>1}
    unless $found;
}

sub RemoveFromBasket {
  my ($self,$id) = @_;
#  die "$self->{data}";
  return undef
    unless $self->{data} && $self->{data}->{basket};

  my @a;
  foreach my $l (0..@{$self->{data}->{basket}}-1) {
    if ($self->{data}->{basket}->[$l]->{id}==$id) {
      $self->{data}->{basket}->[$l]->{count}--;
      next if $self->{data}->{basket}->[$l]->{count}<1;
    }
    push @a,$self->{data}->{basket}->[$l];
  }
  $self->{data}->{basket}=\@a;
  return undef;
}


sub Data {
  my ($self,$key) = @_;
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub GenerateKey {
  my $length = shift;
  $length=64 unless $length>0;
  return substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0,
                $length);
}

sub GetDataSerialized {
    my ($self,$data) = @_;
  return $self->{ser}->serialize($data || $self->Data());
}

sub GetDataDeserialized {
    my ($self,$data) = @_;
  return $self->{ser}->deserialize($data);
}

sub SaveSession {
  my ($self,$context) = @_;

  $self->{store_object}->StoreData($context,$self->Data());
  $context->addCookie(
                      CGI::Cookie->new(-name => "$self->{ssid_name}",
                                      -value => $self->{ssid},
                                      -expires => $self->{expires},
                                     )
                     );

}


1;
