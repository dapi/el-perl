package el::Web::View::TT;
use strict;
use Template;
use Apache2::RequestRec;
use Apache2::Const;
use Date::Parse;
#use Date::Language;
use Date::Handler;
use HTTP::Date;
use Data::Dumper;
use Number::Format qw(:subs);
use el::Config;
use base qw(el::Base);
use vars qw($VERSION );

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;
use URI::Escape;

sub new {
  my ($class,$c)=(shift,shift);
  my $self =  bless {}, $class; # @_в bless не ставить
  foreach (qw(header options http_options)) {
    $self->{$_}= \%{$c->{config}->{view}->{$_}};
  }
  $self->{process_params}={};
  $self->{filters} = Template::Filters->new({
                                             FILTERS => {
                                                         uri => \&uri_escape,
                                                         escape => \&filter_escape,
                                                         text => \&filter_text,
                                                         filesize => \&filter_filesize,
                                                         date =>  \&filter_date,
                                                         date_time =>  \&filter_date_time,
#                                                         date_human => \&filter_date_human,
                                                         time =>  \&filter_time,
                                                         timestamp => \&filter_timestamp,

                                                        },
                                            });
  $self->clone_self();
  return $self;
}

sub Init {
  my $self = shift;
  $self->clear_self();
}

sub process_params {
  my $self = shift;
  return @_ ? $self->{process_params}=$_[0] : $self->{process_params};
}

sub process_internal {
  my ($self,$c) = @_;
  # TODO Check codex
  die "No template defined or no location to redirect" unless $self->{location};
  my $co = $c->outCookies();
  if ($co) {
    foreach (@$co) {
#      print STDERR "$c->{uri}->{current}: Set-Cookie-err: $_\n";
      $c->{r}->err_headers_out->add('Set-Cookie', $_);
    }
  }
  $c->{r}->headers_out->set(Location=>$self->{location});
  #$r->err_headers_out->set('Pragma','no-cache');
  #    $r->err_headers_out->set('Transfer-Encoding','chunked');
  return $self->{code};

}

sub process {
  my ($self,$c,$result) = @_;
  return $self->process_internal($c,$result) unless $self->{file};
#  my $r;
  my $tt = Template->
    new(%{$self->{options}},
        LOAD_FILTERS=>$self->{filters},
        #        RESULT=>
        OUTPUT=>$c->{r})
      || die "Template processing init error ",Template->error();
  my $code = Apache2::Const::DONE;
  $self->sendHeader($c,$code);
  my $h = {result=>$result,
           context=>$c,
           uri=>$c->{uri},
           data=>$c->data(),
           session=>$c->session(),
           user=>$c->user(),
           config=>$c->config(),
           param=>$c->params(),
           %{$self->{process_params}},
          };
  $h->{objects}=$c->object()->objects()
    if $c->object();
  $tt->process($self->{file},$h)
    || die "Template processing error ($self->{options}->{INCLUDE_PATH}) ",$tt->error();
#  print STDERR "process template:  $code\n";
  return $code;
}

sub sendHeader {
  my ($self,$c,$code) = @_;
  foreach (keys %{$self->{header}}) {
    if ($_ eq 'Content-Type') {
      $c->{r}->content_type($self->{header}->{$_});
    } else {
      $c->{r}->headers_out->add($_,$self->{header}->{$_});
    }
  }
  # устанавливается выше
  $c->{r}->headers_out->set('Cache-control', "max-age=$self->{maxage}")
    if defined $self->{maxage};
  $c->{r}->headers_out->set('Cache-control', HTTP::Date::time2str(time() + $self->{expires}))
    if defined $self->{expires};

  if ($self->{nocache}) {
    $c->{r}->no_cache(1);
    $c->{r}->headers_out->set('Cache-control', "no-cache")
  } else {
    #    $c->{r}->set_etag;
  }
  my $co = $c->outCookies();
  if ($co) {
    foreach (@$co) {
#      print STDERR "$c->{uri}->{current}: Set-Cookie: $_\n";
      $c->{r}->headers_out->add('Set-Cookie', $_);
    }
  }
  #$c->{r}->rflush;
}


sub filter_escape {
  my $text = shift;
  $text =~ s{&(^[#0-9a-z]+;)}{&amp;}gso;
  $text =~ s{<}{&lt;}gso;
  $text =~ s{>}{&gt;}gso;
  $text =~ s{\"}{&quot;}gso;
  $text =~ s{\(c\)}{&copy;}gso;
  $text =~ s{\x85}{&hellip;}gso;
  $text =~ s{\x96}{&ndash;}gso;
  $text =~ s{\xab}{&laquo;}gso;
  $text =~ s{\xbb}{&raquo;}gso;
  return $text;
}

sub filter_filesize {
  my $size = shift;
  $size+=0;
  return "0" unless $size;
  return "$size bytes" if $size<3000;
  $size=round($size/1024);
  return "$size Kb" if $size<2000;
  $size=round($size/1024);
  return "$size Mb" if $size<2000;
  $size=round($size/1024);
  return "$size Gb";

}

sub filter_text {
  my $text = shift;

  $text =~ s{\<([\/])?([ibu])\>}{\[$1$2\]}gso;
  $text =~ s{(^|\W)\*([^*\n]+)\*($|\W)}{$1\[b\]$2\[\/b\]$3}gmso;
  # в таком виде она портит ссылки - убирает //
  #  $text =~ s{(^|\W)\/([^\/\n]+)\/($|\W)}{$1\[i\]$2\[\/i\]$3}gmso;
  #  $text =~ s{([^\/]|^|\s)\/([^\/\n]+)\/([^\/]|$|\s)}{$1\[i\]$2\[\/i\]$3}gmso;
  $text =~ s{(^|\s)\/([^\/\n]+)\/($|\s)}{$1\[i\]$2\[\/i\]$3}gmso;
  $text =~ s{(^|\W)_([^_\n]+)_($|\W)}{$1\[u\]$2\[\/u\]$3}gsmo;
  $text =~ s{<br>}{\n}gsmo;

  # с другого спорта
  $text =~ s{<!--emo&[^-]+-->.+<!--endemo-->}{$1}gsmo;
  $text =~ s{<!--QuoteBegin-->[^!]+<!--QuoteEBegin-->([^!]+)<!--QuoteEnd-->[^!]+<!--QuoteEEnd-->}{\[q\]$1\[\/q\]}gsmo;

  $text =~ s{<a href='(.+)'\s+[^<]+</a>}{$1}gsmo;

  $text = filter_escape($text);

  $text =~ s{\[q\]}{<div class=quote>}gsmo;
  $text =~ s{\[\/q\]}{<\/div>}gsmo;

  # Подпись
  $text =~ s{\[\/s\]}{\</i\>}gso;
  $text =~ s{\[s\]}{\n\<i\>}gso;
  $text =~ s{\[\/s\]}{\</i\>}gso;

  $text =~ s{\[hr\]}{<hr>}gso;

  $text =~ s{\[(\/)?([ibu])\]}{\<$1$2\>}gso;
  $text =~ s/\n/<br>\n/gm;

#  $text=~s/((((http|https|ftp):\/\/)|(www\.))([^\/][\@a-z0-9\._\+\-\=\?\&\%\,\/\#\(\)]+))/ProcessLink($1,$dont_process_image)/igme;


#   if ($length) {
#     $text=~s/((.{$length})\s).*/$2&\#8230;/m;
#   }
#
#   if ($dont_process_image) {
#     $text=~s/(^|[^\\])\[img\#(\d+)\]/$1 /mge;
# #    $text=~s/\[user\#([0-9._a-z]+)\]//imge;
#   } else {
#     $text=~s/(^|[^\\])\[img\#(\d+)\]/$1.ReplaceIMG($2)/mge;
#   }
#
#   $text=~s/(^|.)\[user\#([0-9\-._a-zйцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪЖЭДЛОРПАВЫФЯЧСМИТЬБЮ]+)\]/render_user($1,$2)/imge;
#
#   # Если смайл встречается в теге - задница
#
#   $text=~s|(\S*)([:;8k]-?[\(\)D])|smile($1,$2)|emg;
#   $text=~s|(\S*)(\:([a-z_]+)\:)|smile($1,$2)|emg;


  return $text;
}

sub ParseDateTime {
  my $value = shift;
#  my $lang = Date::Language->new('Russian');
  my $d = str2time($value);
  return undef unless $d;
  # TODO!!
#  $d->[0]=2000 if $d->[0]==1970;
  my $object = Date::Handler->
    new({date=>$d,
         time_zone=>config()->{time_zone},
         locale=>config()->{locale}
        });
  #  die "$object";
#  print STDERR "($itz,$li,$langi,$self->{from_sql}->{input}->{shift}) $value/$d -  ($otz,$lo) $object - ";
#  $object->SetLocale($lo) if $lo;
#  $object->TimeZone($otz) if $otz;
  return $object;
}

sub filter_time {
  my $date = shift;
  $date = ParseDateTime($date) || return undef;
  return $date->TimeFormat('%R');
}

sub filter_date_time {
  my $date = shift;
  $date = ParseDateTime($date) || return undef;
  return $date->TimeFormat('%D %T');
}


sub filter_date {
  my $date = shift;
  $date = ParseDateTime($date) || return undef;
  return $date->TimeFormat('%D');
}

sub filter_date_human {
  my $date = shift;
  $date = ParseDateTime($date) || return undef;
  return $date->human();
}



sub filter_timestamp {
  my $date = shift;
  $date = ParseDateTime($date) || return undef;
  return $date->Epoch();
}

1;
