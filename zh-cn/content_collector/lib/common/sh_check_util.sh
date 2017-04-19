#!/bin/bash
#!Author:zhujialong@letv.com,20150107.
# Modified:20150114. add MailFlag.
# Modified:20150206. add touch file before check. add user,ip,cur_dir info.
# Modified:20150210. add mailFlag,exitflag. 
# Modified:20150303. add check_thread_num. 
# Modified:20150608. add check_util_start_time.
# Modified:20150611. add check_util_mail_to and check_util_mail_from. 
# Modified:20150612. add echo check_date.
# Modified:20150717. add check_file_exist and check_update_time. 
# Modified:20150924. change wronginfo to errorinfo. 
# Modified:20151009. add check_hdfs_file_exist and check_hdfs_update_time. 
# Modified:20151109. use new version send_mail.  
# Modified:20151204. use "wronginfo" instead of "errorinfo", in case check "error" log. 

# zhujialong,20150611. source example argv: mail_to, mail_from
# source ./sh_check_util_v2.sh zhujialong@letv.com  liuzhongliang@letv.com
MAIL_UTIL=/home/search/sunhaochuan/git/pipeline/zh-cn/content_collector/lib/common/MailUtil.py

if [ $# -ge 1 ]
then
    check_util_mail_to=$1
else
    check_util_mail_to="zhujialong@letv.com"
fi


check_util_start_time=`date`


function send_mail()
{
    mail_subject=$1
    mail_content=$2
    mail_to_list=$3
    mail_print_info="True"
    phone_list=$4
    echo "echo:" $phone_list $mail_to_list
    python $MAIL_UTIL "$1" "$2" "$3" "$mail_print_info" "$phone_list"
    return $?
}


function get_base_info()
{
    # echo/return base_info.
    cur_ip=`ifconfig  | grep  'inet addr:' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
    base_info="user: `whoami`\nip: $cur_ip\ncur_dir: `pwd`\ndate: `date`\ncheck_util_start_time: $check_util_start_time"
    echo $base_info
}


function check_file_exist()
{
    # param format: file_name, project_name, mailflag, exitflag.
    file_name=$1

    return_code=0
    if [ ! -e $file_name ] 
    then
        return_code=1
        project_name=$2
        mailflag=$3
        exitflag=$4

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nmailflag: $mailflag\nexitflag: $exitflag"
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit 1 
        fi
    fi
    echo "check_date:`date`"
    return $return_code 
}


function check_size()
{
    # params format: file_name, limit_size, project_name, mailflag, exitflag.
    file_name=$1
    limit_size=$2
    project_name=$3
    mailflag=$4
    exitflag=$5

    touch $file_name
    file_size=`ls -al $file_name|awk '{print $5}'`
    # zhujialong,20150114. use "le" instead of "lt" for check size 0.
    if [ "$file_size" -lt "$limit_size" ]
    then

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nfile_size: $file_size\nlimit_size: $limit_size\nmailflag: $mailflag\nexitflag: $exitflag"
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit 1
        fi
    fi
    echo "check_date:`date`"
}


function check_line_num()
{
    # params format: file_name, limit_num, project_name, mailflag, exitflag.
    # check "lt", not "le" limit_num! set limit_num=1 if wanna to check null file.
    file_name=$1
    limit_num=$2
    project_name=$3
    mailflag=$4
    exitflag=$5

    touch $file_name
    file_num=`wc -l $file_name|awk '{print $1}'`
    if [ "$file_num" -lt "$limit_num" ]
    then

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nfile_num: $file_num\nlimit_num: $limit_num\nmailflag: $mailflag\nexitflag: $exitflag"
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit 1
        fi
    fi
    echo "check_date:`date`"
}


function check_return_code()
{
    # params format: info, project_name, mailflag, exitflag.
    return_code=$?
    if [ $return_code -ne 0 ]
    then
        info=$1
        project_name=$2
        mailflag=$3
        exitflag=$4

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nreturn code:$return_code\ninfo: $info\nmailflag: $mailflag\nexitflag: $exitflag" 
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit 1
        fi
    fi
    echo "check_date:`date`"
    return 0
}



function check_update_time()
{
    # params format: file_name, limit_day, limit_hour, project_name, mailflag, exitflag.
    file_name=$1
    limit_day=$2
    limit_hour=$3
    project_name=$4
    mailflag=$5
    exitflag=$6
    
    check_file_exist $file_name $project_name $mailflag $exitflag
    return_code=$?

    if [ "$return_code" -eq "0" ]
    then
        file_update_time=`ls -al --time-style="+%Y%m%d%H%M%S" $file_name |awk '{print $6}'`
        limit_update_time=`date -d "$limit_day days ago $limit_hour hours ago" +%Y%m%d%H%M%S`
        if [ "$file_update_time" -lt "$limit_update_time" ]
        then
            return_code=1

            if [ "$mailflag" == "True" ]
            then
                wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nlimit_day: $limit_day\nlimit_hour: $limit_hour\nlimit_update_time: $limit_update_time\nfile_update_time: $file_update_time\nmailflag: $mailflag\nexitflag: $exitflag"
                python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
            fi

            if [ "$exitflag" == "True" ]
            then
                exit 1 
            fi

        fi
    fi
    echo "check_date:`date`"
    return $return_code
}


function check_thread_num()
{
    # params format: thread_name, limit_num, project_name, mailflag, exitflag, exitcode.
    # Notice:$project_name 应该被扩住，防止其中有空格，导致参数错误.
    # Notice: 手工调用时，limit_num设置为2；使用crontab的时候，limit_num应该设置为3.
    # eg. check_thread_num "$0" 3 ”$project_name“ True True 
    # zhujialong,20151209. 增加可设定exitcode.
    thread_name=$1
    limit_num=$2
    if [ $# -ge 6 ]
    then
        exitcode=$6
    else
        exitcode=1
    fi

    thread_num=`ps aux|grep $thread_name |grep -v 'grep'|wc -l`
    if [ "$thread_num" -gt "$limit_num" ]
    then
        project_name=$3
        mailflag=$4
        exitflag=$5

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nthread_name: $thread_name\nthread_num: $thread_num\nlimit_num: $limit_num\nmailflag: $mailflag\nexitflag: $exitflag"
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit $exitcode 
        fi
    fi
    echo "check_date:`date`"
    return $thread_num
}


function check_hdfs_file_exist()
{
    # param format: file_name, project_name, mailflag, exitflag.
    file_name=$1
    project_name=$2
    mailflag=$3
    exitflag=$4

    return_code=0
    hadoop fs -test -e $file_name
    if [ $? -ne 0 ]
    then
        return_code=1

        if [ "$mailflag" == "True" ]
        then
            wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nmailflag: $mailflag\nexitflag: $exitflag"
            python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
        fi

        if [ "$exitflag" == "True" ]
        then
            exit 1 
        fi
    fi
    echo "check_date:`date`"
    return $return_code 
}


function check_hdfs_update_time()
{
    # params format: file_name, limit_day, limit_hour, project_name, mailflag, exitflag.
    file_name=$1
    limit_day=$2
    limit_hour=$3
    project_name=$4
    mailflag=$5
    exitflag=$6
    
    check_hdfs_file_exist $file_name $project_name $mailflag $exitflag
    return_code=$?

    if [ "$return_code" -eq "0" ]
    then
        file_update_time_str=`hadoop fs -ls $file_name |awk '{print $6,$7}'`
        limit_update_time_str=`date -d "$limit_day days ago $limit_hour hours ago" "+%Y-%m-%d %H:%M:%S"`

        file_update_time=`date -d "$file_update_time_str" +%s`
        limit_update_time=`date -d "$limit_day days ago $limit_hour hours ago" +%s`
        if [ "$file_update_time" -lt "$limit_update_time" ]
        then
            return_code=1

            if [ "$mailflag" == "True" ]
            then
                wronginfo="$project_name $FUNCNAME wrong.\nfile_name: $file_name\nlimit_day: $limit_day\nlimit_hour: $limit_hour\nlimit_update_time_str: $limit_update_time_str\nfile_update_time_str: $file_update_time_str\nmailflag: $mailflag\nexitflag: $exitflag"
                python $MAIL_UTIL "$project_name wrong" "`echo -e $wronginfo`" "$check_util_mail_to"
            fi

            if [ "$exitflag" == "True" ]
            then
                exit 1 
            fi

        fi
    fi
    echo "check_date:`date`"
    return $return_code
}


:<<block
#send_mail "test_send_mail_sub" "test_mail_content" "$check_util_mail_to"
#check_file_exist "dddddd" "test_file_exist" True True
#check_size "$0" 1 "test_check_size" True True
#check_size "$0" 10000000 "test_check_size" True True
#check_line_num "$0" 1 "test_check_line_num" True True
#check_line_num "$0" 10000000 "test_check_line_num" True True
#dafdsasdfdsafds
#check_return_code "dafdsasdfdsafds" "test_return_code" True True
#check_update_time "FilterUtil.py" 0 1 "test_check_update_time" True True

check_hdfs_file_exist /user/rec/output/rec/rec_itemcf/cf_result_merge.txt "test1009" True False
check_hdfs_file_exist /user/rec/output/rec/rec_itemcf/cf_result_merge.txt.non "test1009" True False
check_hdfs_update_time  /user/rec/output/rec/rec_itemcf/cf_result_merge.txt 0 0 "test1009" True False
check_hdfs_update_time  /user/rec/output/rec/rec_itemcf/cf_result_merge.txt 0 1 "test1009" True False
check_hdfs_update_time  /user/rec/output/rec/rec_itemcf/cf_result_merge.txt 1 0 "test1009" True False
block
