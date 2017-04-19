#!/bin/sh
#===============================================================================
#
# Copyright (c) 2014 Letv.com, Inc. All Rights Reserved
#
#
# File: hdfs.sh
# Author: Li Qiang(liqiang1@letv.com)
# Date: 2014/12/29 15:53:59
#
#===============================================================================
HadoopFileSysList()
{
    hadoop fs -ls $*
    return $?
}

HadoopFileSysMakeDir()
{
    hadoop fs -mkdir -p $*
    return $?
}

HadoopFileSysRemove()
{
    hadoop fs -rm $*
    return $?
}

HadoopFileSysRemoveDir()
{
    _path=$*
    if [ ${#_path} -gt 10 ]; then
        echo "remove hadoop dir length is:" ${#_path}
        hadoop fs -rm -r skipTrash $_path > /dev/null 2>&1
        return $?
    else
        echo "remove hadoop dir error:" ${#_path}
        exit 1
    fi
}

HadoopFileSysPut()
{
    hadoop fs -put -f $1 $2 
    if [ $? -ne 0 ]; then
        HadoopFileSysRemove $2 >/dev/null 2>&1
        return 1
    fi

    return 0
}

HadoopFileSysText()
{
    hadoop fs -text $* 
    return $?
}

HadoopFileSysGet()
{
    hadoop fs -get $* 
    return $?
}

HadoopFileSysGetMerge()
{
    hadoop fs -getmerge $* 
    return $?
}

HadoopFileSysCat()
{
    hadoop fs -cat $* 
    return $?
}

# Test if the give path exists. This apply to both files and dirctories
HadoopFileSysExists()
{
    hadoop fs -test -e $1 >/dev/null 2>&1
    return $?
}

# Test if the given path is a directory
HadoopFileSysIsDir()
{
    hadoop fs -test -d $1 >/dev/null 2>&1
    return $?
}

# Test if the give path is an empty file
HadoopFileSysIsEmtpy()
{
    hadoop fs -test -z $1 >/dev/null 2>&1
    return $?
}

HadoopFileSysDu()
{
    hadoop fs -du $*
    return $?
}

HadoopFileSysCopy()
{
    hadoop fs -cp $*
    return $?
}








# vim: set expandtab ts=4 sw=4 sts=4 tw=100:
