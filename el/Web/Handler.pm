package el::Web::Handler;
use strict;
use mod_perl 1.99;
use el::Web::Context;
use Apache2::Const;
use Apache2::RequestUtil;
use Apache2::RequestRec;
use APR::URI;
use Error qw(:try);
use Exporter;

use vars qw($VERSION);

( $VERSION ) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
  my ($class)=(shift);
  my $self =  bless {}, $class; # @_в bless не ставить
  return $self;
}

sub ParseURI {
  my ($self,$r) = @_;
  my %uri;
  my $ip = $r->headers_in()->{'X-Forwarded-For'} || $r->connection()->remote_ip();
  my @i = split(/\,\s+/,$ip);
  $uri{remote_ip} = pop @i;
  $uri{referer} = $r->headers_in()->{'Referer'};
  my $xurl = $r->headers_in()->{'X-URL'};
  if ($xurl) {
    $xurl="http://$xurl" unless $xurl=~/^http:\/\//;
    $uri{current} = APR::URI->parse($r->pool,$xurl);
    $uri{current}->port(undef) if $uri{current}->port()==80;
  } else {
    my $server = $r->parsed_uri;
    $server->hostname($r->get_server_name);
    $server->port($r->get_server_port);
    $server->scheme('http');
    $uri{current} = $server;
  }

  $uri{current}=$uri{current}->unparse();
  if ($uri{current}=~s/\?(.+)$//) {
    $uri{query}=$1;
  }
  #    print STDERR "\nInit: $uri{current}\n";
  return \%uri;
}

sub context {
  die "context должна быть имплементирована в хендлере проекта";
}

sub handler {
  my $class = shift;
  return $class->_handler($class->context(),@_);
}

sub _handler {
  my ($class,$context,$r) = @_;
  my $handler;
  return try {
    my $uri = $class->ParseURI($r);
    $context->Init($r,$uri);
    my $res = try {
      $context->Lookup($uri->{current})
        || return NOT_FOUND;
      return
        $context->View(
                       $context->Execute()
                      );
    } catch el::Web::NoAccess with {
      my $e = shift;
      print STDERR "No access catched: $e\n";
      $e->ShowPage($context);
      return Apache2::Const::FORBIDDEN;
    };
    $context->Deinit($r);
    return $res;
  } catch Error with {
    my $e = shift;
    print STDERR "Catch error: $e\n";
    return ShowError($r,$e->stringify);
  } otherwise {
    print STDERR "Catch error: Otherwise $@\n";
    return ShowError($r,"UNKNOWN ERROR: $@");
#   } finally {
#     print STDERR "finally\n";
  };
  return Apache2::Const::SERVER_ERROR;
}

sub ShowError {
  my ($r,$error)=@_;
  $error=~s/\n/<br>/g;
  $r->custom_response(SERVER_ERROR,
		      "<html><h1>Web Server Error</h1><code>$error</code></html>".' 'x500);
  return SERVER_ERROR;
}


1;
