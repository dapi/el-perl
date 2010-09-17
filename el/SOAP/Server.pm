package el::SOAP::Server;
use strict;
use vars qw(@ISA);
use SOAP::Transport::HTTP;

#use Data::Dumper $Data::Dumper::Terse =1; $Data::Dumper::Indent = 0;
@ISA = qw(SOAP::Transport::HTTP::Daemon);

#use SOAP::Transport::TCP; @ISA = qw(SOAP::Transport::TCP::Server);

$SOAP::Constants::DO_NOT_USE_CHARSET = 1;

sub find_target {
  my $self = shift;
  my($class, $method_uri, $method_name) = $self->SUPER::find_target(@_);
  #   $self->log_request($class,$method_name,$request);
  return ($class, $method_uri, "AUTOLOAD_$method_name");
}

# Позволяет паралелньые запросы

sub handle {
  my $self = shift->new;

 CLIENT:
  while (my $c = $self->accept) {
    my $pid = fork();

    # We are going to close the new connection on one of two conditions
    #  1. The fork failed ($pid is undefined)
    #  2. We are the parent ($pid != 0)
    unless( defined $pid && $pid == 0 ) {
      $c->close;
      next;
    }
    # From this point on, we are the child.

    $self->close;               # Close the listening socket (always done in children)

    # Handle requests as they come in
    while (my $r = $c->get_request) {


      $self->request($r);

      my $res = $self->SOAP::Transport::HTTP::Server::handle;
#      print Dumper('peername',$self->request());#
      #      print "response: ",$self->response->content,"\n";
      $c->send_response($self->response);
    }
    $c->close;
    return;
  }
}

1;
