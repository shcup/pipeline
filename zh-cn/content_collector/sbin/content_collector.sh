#!/bin/sh
cd `dirname $0`
source /etc/profile
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# Author: Haochuan Sun(sunhaochuan@le.com)
# Date: 2017/03/13
#
#===============================================================================
data_date=
input_path=
output_path='pipeline'
second_param=
COMMAND=

if [ $# -ge 1 ]
then
    if [ $# -ge 1 ]
    then
        COMMAND=$1
    fi
    if [ $# -ge 2 ]
    then
        second_param=$2
    fi
    if [ $# -ge 3 ]
    then
        output_path=$3
    fi
else
    echo $#
    echo $@
    echo 'wrong argv'
    exit
fi

CONTENT_COLLECTOR_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)
CONTENT_COLLECTOR_PIPELINE_LOG_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/log
CONTENT_COLLECTOR_PIPELINE_DATA_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/data
CONTENT_COLLECTOR_PIPELINE_LIB_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/lib
CONTENT_COLLECTOR_PIPELINE_BIN_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/bin
CONTENT_COLLECTOR_PIPELINE_JAR_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/jar
CONTENT_COLLECTOR_PIPELINE_CONF_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/conf
CONTENT_COLLECTOR_PIPELINE_TEST_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/test
CONTENT_COLLECTOR_PIPELINE_BUILD_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/build
CONTENT_COLLECTOR_PIPELINE_STATUS_DIR=${CONTENT_COLLECTOR_PIPELINE_HOME}/status
#GALAXY_SPARK_STREAMING_LOG=$GALAXY_PER_DOCUMENT_PIPELINE_LOG_DIR  streaming




CONTENT_COLLECTOR_PIPELINE_LOGFILE=
CONTENT_COLLECTOR_PIPELINE_PIDFILE=

FASTTEXT_MAPPER_FILE=

CURRENT_DATE=$(date +%Y%m%d)
CURRENT_HOUR=$(date +%Y%m%d%H)
CURRENT_TIME=$(date +%Y%m%d%H%M%S)

LOGFILE_SUFFIX=$(date "+%Y%m%d_%H")

declare -A STATIC_HANDLER_CONF

#source ${IMAGETEXT_PIPELINE_HOME}/conf/mr_imagetext_pipeline.conf
source ${CONTENT_COLLECTOR_PIPELINE_LIB_DIR}/shell/logger.sh
source ${CONTENT_COLLECTOR_PIPELINE_LIB_DIR}/shell/fs.sh
source ${CONTENT_COLLECTOR_PIPELINE_LIB_DIR}/shell/hdfs.sh
#source ${GALAXY_PER_DOCUMENT_PIPELINE_LIB_DIR}/shell/mr_imagetext_pipeline_routines.sh




######################################################################################


function ContentCollectorPipelineInit()
{

    LoggerInfo "--------------------------------------------------------------------------------"
    LoggerInfo "Mr Content Collector Pipeline Initialization"
    LoggerInfo

    export JAVA_HOME=${JAVA_HOME}
    export PATH=${HADOOP_HOME}/bin:${HIVE_HOME}/bin:${PATH}

    mkdir -p ${CONTENT_COLLECTOR_PIPELINE_HOME}/{data,job,log,repo,status,temp,lib}
    mkdir -p ${CONTENT_COLLECTOR_PIPELINE_LOG_DIR}/{info,warn,error,debug}
    mkdir -p ${CONTENT_COLLECTOR_PIPELINE_BUILD_DIR}/{input,output,stat}
    mkdir -p ${CONTENT_COLLECTOR_PIPELINE_HOME}/lib/{java,shell,model}
    mkdir -p ${CONTENT_COLLECTOR_PIPELINE_HOME}/data/{batch,incremental}
    
    
    CONTENT_COLLECTOR_PIPELINE_PIDFILE=${CONTENT_COLLECTOR_PIPELINE_STATUS_DIR}/mr_$COMMAND.pid
    if [ -s ${CONTENT_COLLECTOR_PIPELINE_PIDFILE} ] && [ -d /proc/$(cat ${CONTENT_COLLECTOR_PIPELINE_PIDFILE} 2>/dev/null)/cwd ]; then
        LoggerInfo "There's already a mr_$COMMAND pipeline running, quit!"
        exit 5
    else
        echo $$ > ${CONTENT_COLLECTOR_PIPELINE_PIDFILE}
        [ $? -eq 0 ] || { LoggerError "Creating pid file failed, quit!"; return 1; }
    fi
    LoggerInfo "--------------------------------------------------------------------------------"
    return 0
}

function ContentCollectorPipelineClean()
{
    LoggerInfo "Content Collector Pipeline Cleaning"
    rm -rf ${CONTENT_COLLECTOR_PIPELINE_PIDFILE}
}

function FastTextMapReduce()
{
  _HadoopInputPath=$1
  _HadoopOutputPath=$2

  if [[ -z "$_HadoopInputPath" ]] || [[ -z $_HadoopOutputPath ]]; then
    LoggerError "FastTextMapReduce Failure";
    return 1
  fi

  hadoop fs -rm -r -skipTrash $_HadoopOutputPath

  _cmd="
        /usr/local/hadoop/bin/hadoop jar /letv/package/hadoop-2.6.0/contrib/streaming/hadoop-streaming-2.6.0.jar \
        -libjars content_collector/custom.jar \
        -archives hdfs://letvbg-cluster/data/search/short_video/imagetextdoc/parser/bin/content_collector.tar.gz#content_collector \
        -D mapreduce.job.reduces=0 \
        -D mapreduce.job.name=content_collector \
        -D mapreduce.map.memory.mb=8192 \
        -input $_HadoopInputPath \
        -output $_HadoopOutputPath \
        -mapper ./$FASTTEXT_MAPPER_FILE \
        -file  ./$FASTTEXT_MAPPER_FILE \
        -inputformat org.apache.hadoop.mapred.SequenceFileAsTextInputFormat 
  "
  echo $_cmd
  LoggerInfo $_cmd
  $_cmd 2>&1
  [ $? -eq 0 ] || { LoggerError "FastTextMapReduce Failure"; return 1; }
  LoggerInfo "FastTextMapReduce Success" 
  return 0
}

function FastTextLocalProcess()
{
  _InputPaths=$1
  _OutputLocalFile=$2

  hadoop fs -text $_InputPaths  | ./$FASTTEXT_MAPPER_FILE >> $_OutputLocalFile

}

function PushData2Remote()
{
  _LocalFilePath=$1
  _RemoteHadoopPrefix=$2
  _Timestamp=`$date +%Y%m%d%H%M%S`
  _FileName=`date "+%Y%m%d_%H%M%S_"`$RANDOM
  scp $_LocalFilePath overseas_in@10.121.145.144:/home/overseas_in/zh-cn/$_FileName
  ssh overseas_in@10.121.145.144 "cd /home/overseas_in/zh-cn; hadoop fs -put $_FileName /data/overseas_in/recommendation/galaxy/content_tag/$_RemoteHadoopPrefix_$_Timestamp; rm -rf $_FileName"
}

function CrawleerDataBatchUpdate()
{
  FASTTEXT_MAPPER_FILE=fasttext_predict_mapper.py
  _HadoopInputBase=/data/search/short_video/imagetextdoc/output/inc/galaxy
  _HadoopOutput=/data/search/short_video/imagetextdoc/parser/galaxy/cr_batch
  _LocalPath=$CONTENT_COLLECTOR_PIPELINE_DATA_DIR/output/batch/crawler_batch_fasttext

  _TimePrefix=
  if [ -n "$1" ]; then
    _TimePrefix=`date +%Y%m%d%H -d '$1 hours ago'`
  fi
  _HadoopInputPath=${_HadoopInputBase}/${_TimePrefix}*

  FastTextMapReduce $_HadoopInputPath $_HadoopOutput
  [ $? -eq 0 ] || { LoggerError "CrawleerDataBatchUpdate Failure"; return 1; }

  hadoop fs -getmerge $_HadoopOutput $_LocalPath
  PushData2Remote $_LocalPath _thba

  LoggerInfo "CrawleerDataBatchUpdate Success"
  return 0
  
}

function ThirdPartyDataBatchUpdate()
{
  FASTTEXT_MAPPER_FILE=fasttext_rawdata_predict_mapper.py
  _HadoopInputBase=/data/rec/galaxy/content/
  _HadoopOutput=/data/search/short_video/imagetextdoc/parser/galaxy/th_batch
  _LocalPath=$CONTENT_COLLECTOR_PIPELINE_DATA_DIR/output/batch/thirdparty_batch_fasttext

  _TimePrefix=
  if [ -n "$1" ]; then
    _TimePrefix=`date +%Y%m%d%H -d '$1 hours ago'`
  fi
  _HadoopInputPath=${_HadoopInputBase}/${_TimePrefix}*

  FastTextMapReduce $_HadoopInputPath $_HadoopOutput
  [ $? -eq 0 ] || { LoggerError "ThirdPartyDataBatchUpdate Failure"; return 1; }

  hadoop fs -getmerge $_HadoopOutput $_LocalPath
  PushData2Remote $_LocalPath thba_

  LoggerInfo "ThirdPartyDataBatchUpdate Success"
  return 0
  
}
function CrawlerDataIncrementalUpdate()
{
  FASTTEXT_MAPPER_FILE=fasttext_predict_mapper.py
  _HadoopInputBase=/data/search/short_video/imagetextdoc/output/inc/galaxy
  _TodayDate=`date +%Y%m%d`
  _TodayDataPrefix=${_HadoopInputBase}/${_TodayDate}*
  _YesterdayDate=`date +%Y%m%d -d ‘1 day ago’`
  _YesterdayDataPrefix=${_HadoopInputBase}/${_YesterdayDate}*
  _LocalFilePath=$CONTENT_COLLECTOR_PIPELINE_DATA_DIR/output/incremental/crawler_inc_fasttext
  _LastProcessStampFile=$CONTENT_COLLECTOR_PIPELINE_STATUS_DIR/crawler_last_process

  ScrapyHDFSOneDay $_HadoopInputBase $_TodayDataPrefix $_LastProcessStampFile $_LocalFilePath
  [ $? -eq 0 ] || { LoggerError "CrawlerDataIncrementalUpdate Failure"; return 1; }
  ScrapyHDFSOneDay $_HadoopInputBase $_YesterdayDataPrefix $_LastProcessStampFile $_LocalFilePath
  [ $? -eq 0 ] || { LoggerError "CrawlerDataIncrementalUpdate Failure"; return 1; }
  PushData2Remote $_LocalPath crinc_

}
function ThirdPartyDataIncrementalUpdate()
{
  FASTTEXT_MAPPER_FILE=fasttext_rawdata_predict_mapper.py
  _HadoopInputBase=/data/rec/galaxy/content/
  _TodayDate=`date +%Y%m%d`
  _TodayDataPrefix=${_HadoopInputBase}/${_TodayDate}*
  _YesterdayDate=`date +%Y%m%d -d ‘1 day ago’`
  _YesterdayDataPrefix=${_HadoopInputBase}/${_YesterdayDate}*
  _LocalFilePath=$CONTENT_COLLECTOR_PIPELINE_DATA_DIR/output/incremental/thirdparty_inc_fasttext
  _LastProcessStampFile=$CONTENT_COLLECTOR_PIPELINE_STATUS_DIR/thirdparty_last_process

  ScrapyHDFSOneDay $_HadoopInputBase $_TodayDataPrefix $_LastProcessStampFile $_LocalFilePath
  [ $? -eq 0 ] || { LoggerError "CrawlerDataIncrementalUpdate Failure"; return 1; }
  ScrapyHDFSOneDay $_HadoopInputBase $_YesterdayDataPrefix $_LastProcessStampFile $_LocalFilePath
  [ $? -eq 0 ] || { LoggerError "CrawlerDataIncrementalUpdate Failure"; return 1; }
  PushData2Remote $_LocalPath thinc_

}
function ScrapyHDFSOneDay()
{
  _HadoopInputBase=$1
  _HadoopPathPrefix=$2
  _LastProcessTimestamp=`cat $3`
  _LocalOuputFile=$4
  _CurrentProcessTimestamp=

  _HDFS_FILES=`hadoop fs -ls $_HadoopPathPrefix | awk '{print $8}' | awk -F'/' '{print $NF}'`
  echo $_HDFS_FILES

  _InputParts=
  for x in $_HDFS_FILES 
  do
    echo x
    if [[ -z "$_LastProcessTimestamp" ]] || [[ $x -gt $_LastProcessTimestamp ]]; then
      if [[ -z "$_LastProcessTimestamp" ]] || [[ $x -gt $_CurrentProcessTimestamp ]]; then
        _CurrentProcessTimestamp=$x
      fi

      if [ -n "$_InputParts" ]; then
        _InputParts=$_InputParts" "
      fi
      _InputParts=${_InputParts}${_HadoopInputBase}/$x
    fi

  done

  if [ -n "$_InputParts" ]; then
    FastTextLocalProcess "$_InputParts" $_LocalOuputFile
  fi

  if [ -z "$_CurrentProcessTimestamp" ]; then
    echo $_CurrentProcessTimestamp > $3
  fi


}


function ContentCollectorPipelineRoutine()
{

    ContentCollectorPipelineInit
    [ $? -eq 0 ] || { ContentCollectorPipelineClean; return 11; }

    LoggerInfo "Run $COMMAND routine"

    case $COMMAND in
        th_inc)
            ThirdPartyDataIncrementalUpdate
            [ $? -eq 0 ] || { ContentCollectorPipelineClean; return 1; }
            ;;
        th_batch)
            ThirdPartyDataBatchUpdate
            [ $? -eq 0 ] || { ContentCollectorPipelineClean; return 1; }
           ;;
        cr_inc)
           CrawlerDataIncrementalUpdate
           [ $? -eq 0 ] || { ContentCollectorPipelineClean; return 1; }
           ;;
        cr_batch)
           CrawleerDataBatchUpdate
           [ $? -eq 0 ] || { ContentCollectorPipelineClean; return 1; }
           ;;

    esac

    ContentCollectorPipelineClean
    return 0
}


function mainloop() {

    case $COMMAND in
        th_inc|th_batch|cr_inc|cr_batch|batch|streamingstop)
            CONTENT_COLLECTOR_PIPELINE_LOGFILE=${CONTENT_COLLECTOR_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${LOGFILE_SUFFIX}.log
            mkdir -p ${CONTENT_COLLECTOR_PIPELINE_LOG_DIR}
            ;;
        clean)
            ContentCollectorPipelineClean=${CONTENT_COLLECTOR_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${CURRENT_DATE}.log
            MrImageTextPipelineClean >>${CLEAN_LOGFILE}; return 0
            ;;

        *)
            echo "Unknown Command $COMMAND"
            ;;
    esac

    while getopts f:v:h opt
    do
        case $opt in
            f)
                TEST_INPUT_COMPOSITE_DOC_PATH=$OPTARG
                ;;
            v)
                FLAG_VLOG_SERVERITY=$OPTARG
                ;;
            h|*)
                return 1
                ;;
        esac
    done

    shift $[$OPTIND-1]


    #ContentCollectorPipelineRoutine >> ${CONTENT_COLLECTOR_PIPELINE_LOGFILE} 2>&1
    ContentCollectorPipelineRoutine

    if [ $? -ne 0 ] ; then
        LoggerError "${COMMAND} Run failed";
        return 1;
    fi

    return 0;
}

mainloop $*
exit $?


