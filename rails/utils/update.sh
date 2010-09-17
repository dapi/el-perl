#!/bin/sh
echo "Update ${SYSTEM}"

cd /home/danil/projects

utf="${ROOT}/utils/.update_time"
utf2="${ROOT}/utils/.update_time2"

dirs="${PATH}/ el/"
if [ -f $utf ]; then
nw="-newer $utf"
else
nw=""
fi

files=`find $dirs $nw -type f | grep -v \~  | grep -v "/log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
if [ "$files" ]; then
  echo "Files to copy:"
  restart=0
  if echo "$files" | grep .pm  >/dev/null; then
     if [ "$1" != "1" ]; then
        echo "Restart"
        restart=1
     fi
  fi
  list=`echo "$files" | xargs`
   touch $utf2
  (tar cvf - $list | bzip2 -c | ssh danil@orionet.ru ${ROOT}/utils/receiveupdate.sh $restart) && mv $utf2 $utf
else
   echo "No new files.."
fi
