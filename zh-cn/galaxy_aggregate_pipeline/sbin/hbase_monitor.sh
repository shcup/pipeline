#!/bin/sh  
source /etc/profile
source /home/overseas_in/common/sh_check_util.sh sunhaochuan@letv.com
cd $(dirname $0)
MONITOR_FILE=../status/hbase_monitor.log


#--------------------------
result=`
exec hbase shell <<EOF  
count 'GalaxyContent' 
quit
EOF`
r2=`echo $result | awk '{print $(NF -1)}'`
curent_time=`date`
curent_timestamp=`date +%s -d "$curent_time"`

lastline=`tail -n 1 $MONITOR_FILE`

last_time=`echo "$lastline" | awk  -F"\t" '{print $1}'`
last_count=`echo "$lastline" | awk -F"\t" '{print $2}'`
echo "last_time:" $last_time
echo "last_count:" $last_count
mail_subject="hbase_monitor"
mail_content="hbase_monitor error!"
mail_to_list="sunhaochuan@letv.com,jiaokeke1@letv.com,wanghongqing@letv.com"

echo -e `date`"\t"$r2 >> $MONITOR_FILE

if [ "$last_count" = "$r2" ];then
    mail_content="HBase not update, total doc:"$r2" From"$last_time
    send_mail "$mail_subject" "$mail_content" "$mail_to_list" 
    echo "mail_content:" $mail_content
else
    mail_content="galaxy hbase_monitor ok!"
    #send_mail "$mail_subject" "$mail_content" "$mail_to_list" 
    echo "mail_content:" $mail_content
fi




