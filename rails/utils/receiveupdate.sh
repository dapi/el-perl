#!/bin/sh
echo "Receiving update ${SYSTEM}"
dir="/home/danil/projects/"
if bunzip2 -c | tar xf - -C $dir; then
 echo "Update is done"
 if [ "$1" -eq "1" ]; then
   echo "Restart Apache"
   sudo /usr/local/sbin/apachectl restart
   echo "Finish"
 fi
fi
