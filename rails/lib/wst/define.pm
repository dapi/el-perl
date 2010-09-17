package ${SYSTEM};
#use lib qw(${ROOT}/lib/);
use el::Web::View::TT;
use el::Web::Handler;
use el::Web::Object;
use el::Web::Session;
use el::Web::User;
use el::Web::NoAccess;
use el::Web::Processor::Login;
use el::Web::Processor::Users;
use el::Web::Processor::Roles;
use el::Web::Processor::Objects;
use Config::General;
use base qw(el::Web::Handler);

use ${SYSTEM}::Home;

# ��� ���� handler-������ �������

my $context = el::Web::Context->
  new({
       config_file=>"${ROOT}/conf/site.conf",
       object=>{class=>"el::Web::Object"},
       user=>{class=>"el::Web::User"},
       session=>{class=>"el::Web::Session"},
       view=>{class=>"el::Web::View::TT"},

       # ������ ��������� ������� � ��������
#       noaccess=>{class=>"el::Web::NoAccess"},

       # ������ ��������� ����������� �������
       notfound=>{class=>"el::Web::NotFound"},

       # ������ ��������� ������
       error=>{class=>"el::Web::Error"},

       processors=>
       {home=>'${SYSTEM}::Home',
        login=>'el::Web::Processor::Login',
        roles=>'el::Web::Processor::Roles',
        objects=>'el::Web::Processor::Objects',
        users=>'el::Web::Processor::Users',
       },
      });

# ������������ � ��������
sub context { $context }

1;
