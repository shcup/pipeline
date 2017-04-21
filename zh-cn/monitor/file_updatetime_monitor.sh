#!/bin/bash 
#!Author:jiaokeke1@letv.com

source /letv/home/rec/common/sh_check_util.sh sunhaochuan@letv.com
cd $(dirname $0)

function CheckFileMinuteUpdatetime()
{
    _file_name=$1
    _given_time=$(date --date="$2 minutes ago" "+%Y%m%d%H%M")
    _file_date=$(date -r $_file_name "+%Y%m%d%H%M")
    if [ "1$_file_date" -lt "1$_given_time" ]; then
        echo "_file_date werning:", $_file_date
        return 1
    else
        echo "_file_date OK:", $_file_date
        return 0
    fi
}

function CheckMinuteTimeDiff()
{
    _date=$1
    echo "_date:" $_date
    _limit_time=$(date --date="$2 minutes ago" "+%H%M%S")
    echo "_limit_time:" $_limit_time 
    if [ "$_date" -lt "$_limit_time" ]; then
        return 1
    else
        return 0
    fi  
}

function CheckFileHourUpdatetime()
{
    _file_name=$1
    _given_time=$(date --date="$2 hours ago" "+%Y%m%d%H")
    _file_date=$(date -r $_file_name "+%Y%m%d%H")
    if [ "1$_file_date" -lt "1$_given_time" ]; then
        echo "_file_date werning:", $_file_date
        return 1
    else
        echo "_file_date OK:", $_file_date
        return 0
    fi
}
mail_subject="file_updatetime_monitor"
mail_to_list="sunhaochuan@letv.com,wanghongqing@letv.com"
phone_list="13120218846"


MONITOR_FILE=/letv/home/rec/data/sunhaochuan/git/pipeline/zh-cn/galaxy_aggregate_pipeline/batch/output/index_builder/invert_feature_rec_galaxy.sst
CheckFileHourUpdatetime $MONITOR_FILE 3
if [ $? -ne 0 ]; then
    mail_content="file: $MONITOR_FILE not update in 3 hours"
    send_mail "$mail_subject" "$mail_content" "$mail_to_list" "$phone_list"
fi
MONITOR_FILE=/letv/home/rec/data/sunhaochuan/git/pipeline/zh-cn/galaxy_aggregate_pipeline/latest/output/index_builder/invert_feature_rec_bin_galaxy.fbs
CheckFileMinuteUpdatetime $MONITOR_FILE 20
if [ $? -ne 0 ]; then
    mail_content="file: $MONITOR_FILE not update in 20 Minute"
    send_mail "$mail_subject" "$mail_content" "$mail_to_list" "$phone_list"
fi

hdfs_path=/data/rec/recommendation/galaxy/doc_process/streaming
file_updatetime=`hadoop fs -ls $hdfs_path | tail -1 |  awk -F "/" '{print $NF}' | awk -F "_" '{print $NF}'`
echo "file_updatetime" $file_updatetime 
CheckMinuteTimeDiff $file_updatetime 30
if [ $? -ne 0 ]; then
    mail_content="file: $hdfs_path not update in 30 Minute"
    send_mail "$mail_subject" "$mail_content" "$mail_to_list" "$phone_list"
fi

crawler_hdfs_path=/data/search/short_video/imagetextdoc/output/inc/galaxy/
hadoop_file_updatetime=`hadoop fs -ls $crawler_hdfs_path | tail -1 |  awk -F "/" '{print $NF}' | awk -F "_" '{print $NF}'`
echo "hadoop_file_updatetime" $hadoop_file_updatetime
CheckMinuteTimeDiff $hadoop_file_updatetime 30
if [ $? -ne 0 ]; then
    mail_content="file: $crawler_hdfs_path not update in 30 Minute"
    send_mail "$mail_subject" "$mail_content" "sunhaochuan@le.com,houchenglong@le.com" "$phone_list"
fi

