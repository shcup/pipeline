#!/bin/bash 
#!Author:jiaokeke1@letv.com

source /home/overseas_in/common/sh_check_util.sh sunhaochuan@letv.com
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

MONITOR_FILE=/home/overseas_in/zh-cn/galaxy_aggregate_pipeline/batch/output/index_builder/invert_feature_rec_galaxy.sst
CheckFileHourUpdatetime $MONITOR_FILE 3
if [ $? -ne 0 ]; then
    mail_content="file: $MONITOR_FILE not update in 3 hours"
    send_mail "$mail_subject" "$mail_content" "$mail_to_list" 
fi
MONITOR_FILE=/home/overseas_in/zh-cn/galaxy_aggregate_pipeline/latest/output/index_builder/invert_feature_rec_bin_galaxy.fbs
CheckFileMinuteUpdatetime $MONITOR_FILE 20
if [ $? -ne 0 ]; then
    mail_content="file: $MONITOR_FILE not update in 20 Minute"
    send_mail "$mail_subject" "$mail_content" "$mail_to_list"
fi


