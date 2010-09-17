#!/bin/sh
echo "Install web site template"

#cd /home/danil/projects

src="." #/home/danil/projects/website_template/

system="$1"
root="$2"
hostname="$3"

database="$1"
db_user="$1"
db_password="$1"


path=`echo $root | perl -npe 's/\/$//; s/.*\/(.*)/$1/'`


if [ "$system" -a "$root" -a "$hostname" ]; then
 echo "Создают шаблон сайта $hostname с системой $system в $root"

 if [ -d "$root" ]; then
  echo "Такой каталог уже сущестует $root";
  exit 2;
 fi
else
 echo -e "Не указана система путь и хост. Запускать:\ninstall_rails.sh SYSTEM_NAME FULL_PATH HOSTNAME\n";
 exit 1;
fi

if [ -f ./utils/install_rails.sh ]; then
  echo "Копирую.."
  cp -a $src $root
  cd $root
  find . -name "*~" | xargs rm
else
 exit 3
fi



replace "\${ROOT}" "$root" -- lib/wst/define.pm conf/site.conf doc/nginx.inc doc/startup.inc utils/createdb.sh utils/update.sh
replace "\${PATH}" "$path" -- utils/update.sh
replace "\${SYSTEM}" "$system" -- lib/wst/define.pm lib/wst/Home.pm lib/wst/Handler.pm doc/apache2.inc doc/nginx.inc conf/processors.conf doc/startup.inc utils/receiveupdate.sh utils/update.sh
replace "\${HOSTNAME}" "$hostname" -- doc/nginx.inc conf/pages.conf

replace "\${DATABASE}" "$database" -- utils/createdb.sh  utils/db.sh conf/db.conf
replace "\${USER}" "$db_user" -- utils/createdb.sh  utils/db.sh conf/db.conf
replace "\${PASSWORD}" "$db_password" -- utils/createdb.sh  utils/db.sh conf/db.conf

mv lib/wst lib/$system

# Устанвливаем права на личном компе
test `hostname` == 'dapi' && chown -R danil .

# Права на запись апачем
chown -R apache pic/objects/

echo
echo "Create database"
echo
#/etc/init.d/apache2 stop
./utils/createdb.sh >/dev/null

echo
echo "Reconfigure Web servers.."
echo

echo "Выключено, смотри ручками в ./doc/"

#grep $system /etc/apache2/httpd.conf > /dev/null || cat doc/apache2.inc >> /etc/apache2/httpd.conf
#grep $system /etc/apache2/startup.pl > /dev/null  || cat doc/startup.inc >> /etc/apache2/startup.pl
#grep $system /etc/nginx/nginx.conf > /dev/null  || cat doc/nginx.inc >> /etc/nginx/nginx.conf

#echo
#echo "Restart servers"
#echo
#/etc/init.d/apache2 restart
#/etc/init.d/nginx restart
