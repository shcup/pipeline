#!/bin/sh
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# File: lib/shell/image_text_pipeline_routines.sh
# Author: Li Qiang(liqiang1@letv.com)
# Modified: Shang Huaiying(shanghuaiying@le.com)
# Date: 2015/12/12 01:28:32
#
#===============================================================================
IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_BUILD_DIR=${IMAGETEXT_PIPELINE_HOME}/build
IMAGETEXT_PIPELINE_BUILD_INPUT_DIR=${IMAGETEXT_PIPELINE_BUILD_DIR}/input
IMAGETEXT_PIPELINE_BUILD_OUTPUT_DIR=${IMAGETEXT_PIPELINE_BUILD_DIR}/output
IMAGETEXT_PIPELINE_BUILD_STAT_DIR=${IMAGETEXT_PIPELINE_BUILD_DIR}/stat

IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/data
IMAGETEXT_PIPELINE_REPO_DIR=${IMAGETEXT_PIPELINE_HOME}/repo
IMAGETEXT_PIPELINE_REPO_BACKUP_DIR=${IMAGETEXT_PIPELINE_REPO_DIR}/backup

IMAGETEXT_PIPELINE_TEST_DIR=${IMAGETEXT_PIPELINE_HOME}/test

IMAGETEXT_PIPELINE_LIB_DIR=${IMAGETEXT_PIPELINE_HOME}/lib
IMAGETEXT_PIPELINE_JOB_DIR=${IMAGETEXT_PIPELINE_HOME}/job
IMAGETEXT_PIPELINE_LOG_DIR=${IMAGETEXT_PIPELINE_HOME}/log
IMAGETEXT_PIPELINE_TMP_DIR=${IMAGETEXT_PIPELINE_HOME}/temp
IMAGETEXT_PIPELINE_STATUS_DIR=${IMAGETEXT_PIPELINE_HOME}/status

source ${IMAGETEXT_PIPELINE_HOME}/conf/mr_imagetext_pipeline.conf
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/logger.sh
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/fs.sh
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/hdfs.sh

FLAG_VLOG_SERVERITY=2

function GetRankingList()
{
    LoggerInfo "ok"
}

function GetLDAModel()
{
    LoggerInfo "ok"
}

function GetCountryBlockFile()
{
    LoggerInfo "ok"
}













# vim: set expandtab ts=4 sw=4 sts=4 tw=100:
