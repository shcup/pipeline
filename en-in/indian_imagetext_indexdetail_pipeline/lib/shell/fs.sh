#!/bin/sh
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# File: fs.sh
# Author: Li Qiang(liqiang1@letv.com)
# Date: 2015/03/14 15:22:20
#
#===============================================================================

function FileSysRemoveOld(){
    _min_date=$(date --date="$1 days ago" "+%Y%m%d")
    _file_list=$2

    for _file in $_file_list;
    do
        _file_date=$(date -r $_file "+%Y%m%d")

        if [ "1$_file_date" -le "1$_min_date" ]; then
            echo "Removing $_file"
            rm -rf $_file
        fi
    done
}

function FileSysRemoveHoursOld(){
    _min_time=$(date --date="$1 hours ago" "+%Y%m%d%H")
    _file_list=$2

    for _file in $_file_list;
    do
        _file_time=$(date -r $_file "+%Y%m%d%H")

        if [ "1$_file_time" -le "1$_min_time" ]; then
            echo "Removing $_file"
            rm -rf $_file
        fi
    done
}



















# vim: set expandtab ts=4 sw=4 sts=4 tw=100:
