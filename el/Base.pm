package el::Base;
use Clone qw(clone);
use strict;


sub new {
  my ($class,$h) = @_;
  if (ref($h)) {
  } elsif ($h) {
    $h={name=>$h};
  } else {
    $h={};
  }
  my $self =  bless {%$h}, $class; # @_в bless не ставить
  $self->{_self}=clone($self);
  return $self;
}

sub clone_self {
  my $self = shift;
#  print STDERR "Clone $self:",join(', ',keys %$self),"\n";
  $self->{_self}=clone($self);
}

sub clear_self {
  my $self = shift;
  foreach (keys %$self) {
    next if $_ eq '_self';
#    print STDERR "check key $_: $self->{_self}->{$_}\n";
    if (exists $self->{_self}->{$_}) {
      $self->{$_}=$self->{_self}->{$_};
    } else {
      delete $self->{$_};
    }
  }
#  print STDERR "Clear $self:",join(', ',keys %$self),"\n";
}

1;
