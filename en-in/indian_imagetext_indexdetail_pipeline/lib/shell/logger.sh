#!/bin/sh
#===============================================================================
#
# Copyright (c) 2014 Letv.com, Inc. All Rights Reserved
#
#
# File: scripts/logger.sh
# Author: Li Qiang(liqiang1@letv.com)
# Date: 2014/11/20 13:41:05
#
#===============================================================================

function _LoggerPrint(){
	echo "`date "+%Y/%m/%d %H:%M:%S"` [$1] $2"
}

function LoggerInfo(){
    _LoggerPrint INFO "$*"
}

function LoggerWarn(){
    _LoggerPrint WARN "$*"
}

function LoggerError(){
    _LoggerPrint ERROR "$*"
}

function LoggerError(){
    _LoggerPrint EXCEPTION "$*"
}

function LoggerDebug(){
    _LoggerPrint DEBUG "$*"
}














# vim: set expandtab ts=4 sw=4 sts=4 tw=100:
