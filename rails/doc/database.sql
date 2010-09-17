create table webuser_roles (
 id SERIAL primary key not null,
 name varchar(100) not null unique, -- системное название на инглйском
 title varchar(200) not null, -- короткое описание
 timestamp timestamp not null default now() -- Время создания
);

insert into webuser_roles values (1,'admin','Администраторский доступ');

create table webuser (
 id SERIAL primary key not null,
 timestamp timestamp not null default now(), -- Время создания

 modifytime timestamp not null default now(), -- время изменения личных данных

 login varchar(255) not null unique,
 password varchar(100) not null,

 name varchar(255),

 is_root boolean not null default 'f',

 email varchar(100),

 address text,
 phone varchar(50),

 sign_ip inet,

-- с какого залогинилься
 last_ip inet,

-- последний раз был
 lasttime timestamp not null default now(),

 session char(32) not null unique,

-- время создания сессии
 sessiontime timestamp not null default now(),

 session_data text,



 is_logged boolean not null default 'f',

 is_removed boolean not null default 'f',

 roles varchar(200) not null default ''
);


insert into webuser (login,password,session,is_root) values ('admin','admin','Administrator','t');

create table webuser2roles (
 user_id integer not null,
 role_id integer not null,
 unique (user_id, role_id),
 foreign key (user_id) references webuser (id) on delete cascade on update cascade,
 foreign key (role_id) references webuser_roles (id) on delete cascade on update cascade
);

insert into webuser2roles values (1,1);


create table webobject (
  id SERIAL primary key not null,
  path varchar(100) not null unique,
  title varchar(255) not null,
  anon_access boolean not null default 'f',
  -- закрыто для изменений пути и удаления
  is_closed boolean not null default 'f',
  show_children boolean not null default 't',

  create_time timestamp not null default current_timestamp,
  modify_time timestamp not null default current_timestamp,

  modify_user_id integer not null default 1,

-- доступно всем


  text text,

  parent_id integer,

  list_order integer not null default 0,

  foreign key (parent_id) references webobject (id) on delete no action on update cascade,
  foreign key (modify_user_id) references webuser (id) on delete no action on update cascade
);

insert into webobject values (1,'/','Страницы','t','t');

create table webobject_image (
  object_id integer not null,
  name varchar(150) not null,
  width integer not null,
  height integer not null,

  unique (object_id,name),

  foreign key (object_id)
  references webobject (id) on delete cascade on update cascade
);

create table webobject2roles (
 object_id integer not null,
 role_id integer not null,
 unique (object_id, role_id),
 foreign key (object_id) references webobject (id) on delete cascade on update cascade,
 foreign key (role_id) references webuser_roles (id) on delete cascade on update cascade
);

commit;
