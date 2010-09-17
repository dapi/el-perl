package el::SOAP::BaseClass;
use strict;

use POSIX qw(strftime);
use Error qw(:try);
use Exporter;

use el::SOAP::Error;

use vars qw(@ISA
            $KEY_AS_PARAMETER
            $AUTOLOAD);

@ISA = qw(Exporter);


sub AUTOLOAD {
  my $self = shift;
  my ($class, $m) = ($AUTOLOAD =~ /(.*)::([^:]+)/);
  my $method = $m;
  unless (UNIVERSAL::isa($self,'el::SOAP::BaseClass')) {
    die "No such method $m in class $class";
  }
#  print "NO SUCH METHOD ($method) IN CLASS ($class)\n";
#  print STDERR "AUTOLOAD: $self $class $m\n";
  return undef unless $method=~s/^AUTOLOAD_//; #  $method eq 'DESTROY' || $method eq 'unimport';
  $m=~s/^AUTOLOAD_/METHOD_/;
  $self =  bless {method=>$method,class=>$class}, $self;
  my $time = strftime "%Y-%m-%d %H:%M:%S", localtime;
  print "$$: $time > ${class}::$method(".join(',',map {"'".mydump($_)."'"} @_)."): ";
  my ($version,$key,@params,@to_check);

  if ($KEY_AS_PARAMETER) {
    ($version,$key,@params) = @_;
  } else {
    (@params) = @_;
  }
  try {
    $self->Init();
    throw el::SOAP::Error::AccessDenied()
      unless $self->CheckPermission(@_);
  } catch el::SOAP::Error::AccessDenied with {
    my $e = shift;
    print "ACCESS DENIED: ",$e->stringify(),"\n";
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring("ACCESS DENIED");
  } catch el::SOAP::Error with {
    my $e = shift;
    print "INIT ERROR: ",$e->stringify(),"\n";
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring($e->stringify());
  } catch Error with {
    my $e = shift;
    print "INIT ERROR: $e " if $e;
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring('INTERNAL SERVER ERROR: $e');
  } except {
    my $e = shift;
    print "UNKNOWN INIT ERROR: $e " if $e;
    print "INTERNAL INIT ERROR: '$@'\n";
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring('INTERNAL SERVER ERROR');
  } otherwise {
    print "STRANGE INIT ERROR\n";
  };

  my $ref = $self->can($m);
  unless ($ref) {
    print "NO SUCH METHOD ($method) IN CLASS ($class)\n";
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring("NO SUCH METHOD ($m) IN THIS CLASS");
  }

  return $self->Execute($ref,@params);
}

sub mydump {
  my $a= shift;
  #  return "'".$a->string()."'" if UNIVERSAL::isa($a,'openbill::DataType::DateObject');
  return join(',',map {"$_=>".(defined $a->{$_}  ? ($a->{$_}=~/^[0-9.,\-]+$/ ? "$a->{$_}" : "'$a->{$_}'") : undef)} keys %$a) if  ref($a)=~/hash/i;
  return join(',',@$a) if  ref($a)=~/array/i;
  return ref($a).$a;
}


sub CheckPermission {

  # See into the $som->headerof('//session')->value()
  #   my $h = $som->headerof('//session');
  #   unless ($h) {
  #     fatal("No session's header");
  #   }
  #   my $session = $h->value();

  throw el::SOAP::Error(-text=>'CheckPermission is not implemented');
}

sub Init { 1;}

sub Rollback { 1; }
#sub Commit { 1; }
sub Finally { 1; }

sub Execute {
  my ($self,$ref,@params) = @_;
#  my @params=@_;
  return try {
    my $res = &$ref($self,@params);
    print "OK\n";
    return $res;
  } catch el::SOAP::Error with {
    my $e = shift;
    print "EXECUTION ERROR: ",$e->stringify(),"\n";
    $self->Rollback();
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring($e->stringify());
  } catch Error with {
    my $e = shift;
    print "ERROR: $e " if $e;
    SOAP::Fault
        ->faultcode("$self->{class}:$self->{method}")
          ->faultstring("INTERNAL SERVER ERROR: $e");
#    return undef;
    die $e;
  } except {
    my $e = shift;
    print "UNKNOWN ERROR: $e " if $e;
    print "INTERNAL ERROR: '$@'\n";
    $self->Rollback();
    die SOAP::Fault
      ->faultcode("$self->{class}:$self->{method}")
        ->faultstring("INTERNAL SERVER ERROR: $e ($@)");
  } otherwise {
    print "STRANGE ERROR\n";
  } finally {
    $self->Finally();
  };
}


1;
