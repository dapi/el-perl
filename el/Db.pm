package el::Db;
use strict;
use DBI;
use UNIVERSAL qw(isa);
use Exporter;
use el::Base;
use vars qw(@ISA
	    @EXPORT
	    $VERSION
            $DEBUG
	    $DB
	   );

@ISA = qw(Exporter
	  el::Base);

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT = qw(sqlQuery
             sqlQueryRes
             sqlSelectOne
             sqlSelectAll

             sqlCommit
             sqlBeginWork
             sqlBegin
             sqlRollback

             sqlConnect
             sqlDisconnect

             sqlGetLastID

             sqlInsert
             sqlUpdate
             sqlSeqName

						 sqlGetiLastError
						 
             pg_conv_SqlToArray
						 
             db
            );

#$DEBUG=1;

#use Exception::Class::DBI;

# sub init {
#   my $self = shift;
#   my $param = shift;
#   foreach (qw(datasource user password attributes)) {
#     $self->{$_} = $param->{$_} if exists $param->{$_};
#   }
#   # PrintError  => 0,
#   # RaiseError  => 0,
#   # $self->{attr}->{RaiseError}=0;
#   # $self->{attr}->{HandlerError}=Exception::Class::DBI->handle;# dpl::Error::Db->handler();
# }

sub db {$DB}

sub pg_conv_SqlToArray {
  my $a = shift;
  die "unknown postgres array format: $a" unless $a=~s/^\{(.*)\}$/$1/;
  return [split(',',$a)];
}

sub sqlGetLastError {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  return $DB->err().' '.$DB->errstr();
}

sub sqlCommit {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  #  return $self->{dbh}->{AutoCommit} ? undef : $self->{dbh}->commit();
  print STDERR "SQL commit\n" if $DEBUG;
  return $self->{dbh}->{AutoCommit} ? undef : $self->{dbh}->commit();
}

sub sqlBeginWork {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  print STDERR "SQL begin\n" if $DEBUG;
  return $self->{dbh}->begin_work();
}

sub sqlBegin {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
    print STDERR "SQL begin\n" if $DEBUG;
  return $self->{dbh}->begin_work();
}


sub sqlRollback {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  print STDERR "SQL rollback\n" if $DEBUG;
  return $self->{dbh}->rollback();
}

sub sqlGetLastID {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($seq) = @_;
  if ($self->{datasource}=~/mysql/) {
    my $res = $self->sqlSelectOne("select LAST_INSERT_ID() as id",);
    return $res ? $res->{id} : undef;
    
  } elsif ($self->{datasource}=~/DBI:Pg/) {
    my $res = $self->sqlSelectOne("select currval(?)",$seq);
    return $res ? $res->{currval} : undef;
  }
  die "Not implented GetLastID for $self->{datasource}";
  return undef;
}

sub sqlSeqName {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($table,$id) = @_;
  return "${table}_${id}_seq";
}

# Вызывает auto increment, если указан id

sub sqlInsert {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($table,$data,$id) = @_;
  my $set = join(',',keys %$data);
  my $values = join(',',map {'?'} keys %$data);
  my $sth = $self->sqlQuery("insert into $table ($set) values ($values)", map {$data->{$_}} keys %$data);
  if ($id) {
    return sqlGetLastID(sqlSeqName($table,$id));
  } else {
    return undef;
  }
}

sub sqlUpdate {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($table,$data,$where,@bind) = @_;
  my @f;
  my @b;
  foreach (keys %$data) {
    my $v = $data->{$_};
    if (ref($v)) {
      push @f, ["$_=$v->[0]"];
    } else {
      push @f, $_;
      push @b, $v;
    }
  }
  unshift @bind,@b
    if @b;
  my $fields = join(',',map {ref($_) ? $_->[0] : "$_=?" } @f);
  $where = $where ? "where $where" : '';
  my $sth = $self->sqlQuery("update $table set $fields $where", @bind);
}


sub sqlConnect {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  $self = el::Db->new(@_) unless $self;
  $DB=$self unless $DB;
  
  # почемуто в ob_control.pl повторынй коннект не удавался
  my $dbh = DBI->
    connect_cached($self->{datasource},
            $self->{user},
            $self->{password},
                   $self->{attributes});
  
#  my $rc = $dbh ? $dbh->ping : 'no dbh';
  print STDERR "\nSQL connect $self->{datasource}, attributes: ".join(',',%{$self->{attributes}})." $dbh\n" if $DEBUG;

  return $self->{dbh} = $dbh;
}

sub sqlReconnect {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  
  # почемуто в ob_control.pl повторынй коннект не удавался
  my $dbh = DBI->
    connect($self->{datasource},
            $self->{user},
            $self->{password},
            $self->{attributes});
  
  print STDERR "\nSQL reconnect $self->{datasource} (AutoCommit:$self->{attributes}->{AutoCommit}): $dbh\n" if $DEBUG;
  return $self->{dbh} = $dbh;
}


sub sqlDisconnect {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  print STDERR "SQL disconnect $self->{datasource}\n\n" if $DEBUG;
  return $self->{dbh}->disconnect();
}

sub sqlQuery {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($query,@bind)=@_;
  #  $self->logger()->debug($query,join(';',@bind));

  # Почемуто в ob_contol.pl иначе на второй раз слетает соедининие
  if ($DEBUG) {
    $self->sqlReconnect()
      unless $self->sqlPing();
  }
  print STDERR "SQL $query (".join(',',@bind).")= " if $DEBUG;

  my $sth = $self->{dbh}->prepare($query);
  my $rv = $sth->execute(@bind);
  $self->{last_rv}=$rv;
  print STDERR "$rv\n" if $DEBUG;
  #rv (insert into cards (number,code) values (?,?)):1
  return $sth;
}

sub sqlPing {
  my $self = shift;
  my $rc = $self->{dbh}->ping();
  print STDERR "SQL ping: $rc\n" if $DEBUG;
#   unless $rc;
  return $rc;
}

sub sqlQueryRes {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my ($query,@bind)=@_;
  #  $self->logger()->debug($query,join(';',@bind));
  print STDERR "SQL $query (".join(',',@bind).")= " if $DEBUG;
  my $sth = $self->{dbh}->prepare($query);
  my $rv = $sth->execute(@bind);
  $self->{last_rv}=$rv;
  print STDERR "$rv\n" if $DEBUG;
  return $rv;
}


sub sqlSelectOne {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my $sth = $self->sqlQuery(@_);
  return $sth unless $sth;
  my $res = $sth->fetchrow_hashref();
  $sth->finish();
  return $res;
}

sub sqlSelectAll {
  my $self = isa($_[0],'el::Db') ? shift : $DB;
  my $sth = $self->sqlQuery(@_);
  return $sth unless $sth;
  my @list;
  while ($_=$sth->fetchrow_hashref()) {
    push @list,$_;
  }
  $sth->finish();
  return \@list;
}


1;
