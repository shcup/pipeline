#!/bin/sh
cd `dirname $0`
source /etc/profile
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# File: sbin/mr_indian_imagetext_indexdetail_pipeline.sh
# Author: Shang Huaiying(shanghuaiying@letv.com)
# Date: 2016/07/13
#
#===============================================================================

COMMAND=
if [ $# -ge 1 ]
then
    if [ $# -ge 1 ]
    then
        COMMAND=$1
    fi
    if [ $# -ge 2 ]
    then
        pipeline=$2
    fi
    if [ $# -ge 3 ]
    then
        pipeline=$3
    fi
else
    echo $#
    echo $@
    echo 'wrong argv'
    exit
fi

GALAXY_AGGREGATE_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)
GALAXY_AGGREGATE_PIPELINE_LOG_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/log
GALAXY_AGGREGATE_PIPELINE_LIB_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/lib
GALAXY_AGGREGATE_PIPELINE_BIN_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/bin
GALAXY_AGGREGATE_PIPELINE_JAR_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/jar
GALAXY_AGGREGATE_PIPELINE_CONF_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/conf
GALAXY_AGGREGATE_PIPELINE_DATA_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/$COMMAND
GALAXY_AGGREGATE_PIPELINE_STATUS_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/status


GALAXY_AGGREGATE_PIPELINE_BUILD_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/build
GALAXY_AGGREGATE_PIPELINE_TEST_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/test
#GALAXY_AGGREGATE_PIPELINE_DATA_DIR=${GALAXY_AGGREGATE_PIPELINE_HOME}/$COMMAND

IMAGETEXT_PIPELINE_LOGFILE=
IMAGETEXT_PIPELINE_PIDFILE=

CURRENT_DATE=$(date +%Y%m%d)
CURRENT_HOUR=$(date +%Y%m%d%H)
CURRENT_TIME=$(date +%Y%m%d%H%M%S)

FLAG_BUILD_INDEX=

LOGFILE_SUFFIX=$(date "+%Y%m%d_%H")

declare -A STATIC_HANDLER_CONF

#source ${GALAXY_AGGREGATE_PIPELINE_HOME}/conf/mr_imagetext_pipeline.conf
source ${GALAXY_AGGREGATE_PIPELINE_LIB_DIR}/shell/logger.sh
source ${GALAXY_AGGREGATE_PIPELINE_LIB_DIR}/shell/fs.sh
source ${GALAXY_AGGREGATE_PIPELINE_LIB_DIR}/shell/hdfs.sh
#source ${GALAXY_AGGREGATE_PIPELINE_LIB_DIR}/shell/mr_imagetext_pipeline_routines.sh

MAPRED_INPUT_PATH=
MAPRED_OUTPUT_PATH=
MAPRED_NUM_MAPPER=
MAPRED_NUM_REDUCER=

#pipeline specific configurationj
HADOOP_BASE_DIR=/data/overseas_in/recommendation/galaxy/$COMMAND
HADOOP_HOT_DATA=/data/overseas_in/recommendation/galaxy/hot/
HADOOP_BINARY_DIR=${HADOOP_BASE_DIR}/bin
HADOOP_GALAXY_ORIGIN_COMPOSITEDOC=${HADOOP_BASE_DIR}/aggregate_output

HADOOP_IMAGETEXT_DEDUP_DIR=/data/overseas_in/search/short_video/full
HADOOP_IMAGETEXT_FULL_DEDUP=
HADOOP_IMAGETEXT_INC=

HADOOP_IMAGETEXT_WORKING_DIR=/data/overseas_in/recommendation/pipeline/${data_path}
HADOOP_IMAGETEXT_INDEX_DIR=/data/overseas_in/recommendation/index_builder/${pipeline}/index_data
HADOOP_IMAGETEXT_INDEXBUILDER_DIR=/data/overseas_in/recommendation/index_builder/${pipeline}

TEST_INPUT_COMPOSITE_DOC_PATH=

CATEGORY_RANK_FILE=data/dict/category_rank_info.dat


IMAGETEXT_PIPELINE_REPO_BACKUP_MD5SUM=${IMAGETEXT_PIPELINE_REPO_BACKUP_DIR}/md5sum

LONG_VIDEO_PROCESSED_TIME=
SHORT_VIDEO_PROCESSED_TIME=



function MrImageTextPipelineInit()
{

    LoggerInfo "--------------------------------------------------------------------------------"
    LoggerInfo "Mr ImageText Pipeline Initialization"
    LoggerInfo

    export JAVA_HOME=${JAVA_HOME}
    export PATH=${HADOOP_HOME}/bin:${HIVE_HOME}/bin:${PATH}

    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_HOME}/{job,log,repo,status,temp,lib}
    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_LOG_DIR}/{info,warn,error,debug}
    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_BUILD_DIR}/{input,output,stat}
    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input/{index_builder,detail_builder}
    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/{index_builder,detail_builder}
#mkdir -p ${GALAXY_AGGREGATE_PIPELINE_REPO_BACKUP_DIR}
    mkdir -p ${GALAXY_AGGREGATE_PIPELINE_TEST_DIR}/data/{input,output}

    HadoopFileSysMakeDir ${HADOOP_BINARY_DIR}
    HadoopFileSysMakeDir ${HADOOP_BASE_DIR}

    GALAXY_AGGREGATE_PIPELINE_PIDFILE=${GALAXY_AGGREGATE_PIPELINE_STATUS_DIR}/mr_$COMMAND.pid
    if [ -s ${GALAXY_AGGREGATE_PIPELINE_PIDFILE} ] && [ -d /proc/$(cat ${GALAXY_AGGREGATE_PIPELINE_PIDFILE} 2>/dev/null)/cwd ]; then
        LoggerInfo "There's already a mr_$COMMAND pipeline running, quit!"
        exit 5
    else
        echo $$ > ${GALAXY_AGGREGATE_PIPELINE_PIDFILE}
        [ $? -eq 0 ] || { LoggerError "Creating pid file failed, quit!"; return 1; }
    fi

    LoggerInfo "--------------------------------------------------------------------------------"
    return 0
}

function MrImageTextPipelineClean()
{
    LoggerInfo "Galaxy aggregate Pipeline Cleaning"
    rm -rf ${GALAXY_AGGREGATE_PIPELINE_PIDFILE}
}

function PullIndexData()
{
    _input_hadoop_path=
    _image_text_path=${HADOOP_GALAXY_ORIGIN_COMPOSITEDOC}/part*
    _local_file_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input
    
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path=${_image_text_path}
    else
        LoggerError "imagetext handler output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty hadoop Input"; return 1; }


    rm -f ${_local_file_path}/hdfs_data_input
    hadoop fs -cat ${_input_hadoop_path} | sed 's/[\(\)]//g' | sed 's/,/\t/g' >  ${_local_file_path}/hdfs_data_input

}

function RunImageTextIndexBuilder()
{
    if [ $FLAG_BUILD_INDEX != "BUILD_INDEX" ]
    then
        LoggerInfo "Not build the index" 
       return 0
    fi

    _output_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/index_builder
    _input_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input
    echo "_output_local_path:" $_output_local_path
    echo "_input_local_path:" $_input_local_path

    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

    _command="                                                                                  \
    ${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/recommendation_index_builder_main \
    --input_full_composite_doc_path=${_input_local_path}/hdfs_data_input \
    --input_fresh_composite_doc_paths= \
    --output_composite_doc_path=${_output_local_path}/output_composite_doc \
    --repository_dir=${_output_local_path}  \
    --done_path=${_output_local_path}/done \
    --index_builders=FeatureIndexBuilder \
    --min_final_doc_count=1 \
    --feature_rec_min_inverted_list_size=1 \
    --feature_rec_product_indexes=10:invert_feature_rec \
    --feature_rec_score_computer=FreshnessIndexScoreComputer \
    --index_fscore_compare=true \
    --feature_rec_index_scoring_conf_path=${GALAXY_AGGREGATE_PIPELINE_CONF_DIR}/index_scoring.conf \
    --feature_rec_indexfile_suffix=galaxy \
    --keep_lower_for_index_key=true \
    --v=0 \
    --dump_data_for_statistic_file=statistic_file \
        "

    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextIndexBuilder Run Failure"; return 1; }

    LoggerInfo "MrImageTextIndexBuilder Run Success"
    return 0

}

function RunImageTextDetailBuilder()
{
    if [ $FLAG_BUILD_INDEX != "BUILD_INDEX" ]
    then
        LoggerInfo "NOT BUILD THE DETAIL!"
        return 0
    fi

    _output_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/detail_builder
    _input_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input

    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

    _command="                                                                                  \
    ${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/recommendation_detail_builder_main \
    --input_composite_doc_path=${_input_local_path}/hdfs_data_input \
    --output_detail_path=${_output_local_path}/output_detail \
    --output_media_doc_info_path=${_output_local_path}/output_media_doc_info \
    --done_path=${_output_local_path}/done \
    --detail_data_adapter=ResultDocInfoAdapter \
    --v=0 \
    "

    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextDetailBuilder Run Failure"; return 1; }

    _command_convert_fbs="${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/convert_sst_to_fbs ${_output_local_path}/output_media_doc_info"
    LoggerInfo $_command_convert_fbs
    nohup $_command_convert_fbs

    LoggerInfo "MrImageTextDetailBuilder Run Success"
    return 0

}

function RunHBaseExtraction()
{
    # judge whether to build the index and detail
    FLAG_BUILD_INDEX="FALSE"
    LoggerInfo "Judge whether to build the index and detail"
    index_data_time=`stat ${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/index_builder/done | grep -i Modify | awk -F. '{print $1}' | awk '{print $2" "$3}'`
    index_data_timestamp=`date -d "$index_data_time" +%s`
    now_timestamp=`date +%s`
    LoggerInfo "index data time:"$index_data_time", index data timestamp:"$index_data_timestamp", now timestamp:"$now_timestamp
    latency_diff=`expr $now_timestamp - ${index_data_timestamp}`
    if [[ $latency_diff -gt 7200 ]] || [[ "X"$index_data_time == "X" ]]
    then
        LoggerInfo "Index obsolete, to build the index!!!"
        FLAG_BUILD_INDEX="BUILD_INDEX"
        HadoopFileSysRemoveDir ${HADOOP_GALAXY_ORIGIN_COMPOSITEDOC}
    else
        LoggerInfo "Index fresh, exit!!!"
    fi

    BUILD_DOC2VEC="FALSE"
    LoggerInfo "Judge whether to build the doc2vec"
    if [ ! -f $GALAXY_AGGREGATE_PIPELINE_HOME/aggregate_doc2vec/occupy.lock ]
    then
        BUILD_DOC2VEC="BUILD_DOC2VEC"
        HadoopFileSysRemoveDir ${HADOOP_BASE_DIR}/articles
    fi


    _jars=$(echo ${GALAXY_AGGREGATE_PIPELINE_JAR_DIR}/*.jar /usr/local/spark/lib/*.jar /letv/usr/local/spark-1.6.1-bin-hadoop2.6/libext/*.jar /usr/local/spark/libext | sed 's/ /,/g')

    _command="
              spark-submit \
              --class prod.HBaseDBExtraction \
              --master yarn-client \
              --executor-memory 2g \
              --num-executors 10 \
              --driver-memory 2g \
              --jars $_jars \
              ${GALAXY_AGGREGATE_PIPELINE_JAR_DIR}/SparkScalsJar.jar \
              yarn-client \
              ${HADOOP_BASE_DIR}
              0 \
              GalaxyContent \
              info \
              content \
              $FLAG_BUILD_INDEX \
              $BUILD_DOC2VEC \
              ${HADOOP_BASE_DIR}/aggregate_result \
              "
    LoggerInfo "_command:" $_command
    $_command
    [ $? -eq 0 ] || { LoggerError "HBase Extraction Run Failure"; return 1; }

    # run the aggregation part in parallel
    echo `ls $GALAXY_AGGREGATE_PIPELINE_HOME |grep ^aggregate_`
    for x in `ls $GALAXY_AGGREGATE_PIPELINE_HOME |grep ^aggregate_`
    do
      echo $x
      cd $GALAXY_AGGREGATE_PIPELINE_HOME/$x
      AGGREGATE_PIPELINE_LOGFILE=${GALAXY_AGGREGATE_PIPELINE_LOG_DIR}/"Aggregate_"${x}_${LOGFILE_SUFFIX}.log
      _command="./run.sh ${GALAXY_AGGREGATE_PIPELINE_HOME} ${HADOOP_BASE_DIR} >> $AGGREGATE_PIPELINE_LOGFILE  2>&1 &"
      echo $_command
      nohup ./run.sh ${GALAXY_AGGREGATE_PIPELINE_HOME} ${HADOOP_BASE_DIR} >> $AGGREGATE_PIPELINE_LOGFILE  2>&1 &
      cd $GALAXY_AGGREGATE_PIPELINE_HOME/sbin
    done


    LoggerInfo "RunHBaseExtraction Success"
    return 0
}

function RunHBaseExtractionLatest()
{
    tomorrow_date=`date -d ' +1 day' +%Y%m%d`
    end_row=${tomorrow_date:2}
    yesterday_date=`date -d ' -1 day' +%Y%m%d`
    start_row=${yesterday_date:2}
    _jars=$(echo ${GALAXY_AGGREGATE_PIPELINE_JAR_DIR}/*.jar /usr/local/spark/lib/*.jar /letv/usr/local/spark-1.6.1-bin-hadoop2.6/libext/*.jar /usr/local/spark/libext | sed 's/ /,/g')

    echo "hehe" ${HADOOP_GALAXY_ORIGIN_COMPOSITEDOC}
    HadoopFileSysRemoveDir ${HADOOP_GALAXY_ORIGIN_COMPOSITEDOC}
    _command="
              spark-submit \
              --class prod.HBaseDBExtraction \
              --master yarn-client \
              --executor-memory 2g \
              --num-executors 10 \
              --driver-memory 2g \
              --jars $_jars \
              ${GALAXY_AGGREGATE_PIPELINE_JAR_DIR}/SparkScalsJar.jar \
              yarn-client \
              ${HADOOP_BASE_DIR}
              86400 \
              GalaxyContent \
              info \
              content \
              BUILD_INDEX \
              NOT \
              /data/overseas_in/recommendation/galaxy/batch/aggregate_result \
              $start_row \
              $end_row \
              "

    LoggerInfo "_command:" $_command
    $_command
    [ $? -eq 0 ] || { LoggerError "HBase Extraction Latest Run Failure"; return 1; }
    LoggerInfo "RunHBaseExtractionLatest Success"
    return 0

}

function RunImageTextIndexBuilderLatest()
{
    _output_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/index_builder
    _input_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input
    echo "_output_local_path:" $_output_local_path
    echo "_input_local_path:" $_input_local_path

    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

 
    _command="                                                                                  \
    ${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/recommendation_index_builder_main                      \
    --input_full_composite_doc_path=${GALAXY_AGGREGATE_PIPELINE_HOME}/batch/input/hdfs_data_input               \
    --input_fresh_composite_doc_paths= ${_input_local_path}/hdfs_data_input \
    --output_composite_doc_path=${_output_local_path}/output_composite_doc            \
    --repository_dir=$_output_local_path   \
    --done_path=${_output_local_path}/done                                             \
    --index_builders=FeatureIndexBuilder                                               \
    --min_final_doc_count=1 \
    --feature_rec_min_inverted_list_size=1 \
    --feature_rec_product_indexes=10:invert_feature_rec \
    --feature_rec_score_computer=FreshnessIndexScoreComputer \
    --index_fscore_compare=true \
    --feature_rec_index_scoring_conf_path=${GALAXY_AGGREGATE_PIPELINE_CONF_DIR}/index_scoring.conf \
    --feature_rec_indexfile_suffix=galaxy \
    --keep_lower_for_index_key=true \
    --v=0 \
        "

    echo $_commend
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextIndexBuilder Run Failure"; return 1; }

    LoggerInfo "MrImageTextIndexBuilder Run Success"
    return 0

}

function RunImageTextDetailBuilderLatest()
{
    _output_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/output/detail_builder
    _input_local_path=${GALAXY_AGGREGATE_PIPELINE_DATA_DIR}/input

    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

 
    _command="                                                                                  \
    ${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/recommendation_detail_builder_main \
    --input_composite_doc_path=${_input_local_path}/hdfs_data_input \
    --output_detail_path=${_output_local_path}/output_detail \
    --output_media_doc_info_path=${_output_local_path}/output_media_doc_info \
    --done_path=${_output_local_path}/done \
    --detail_data_adapter=ResultDocInfoAdapter \
    --v=0 \
    "

    echo $_commend
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextDetailBuilder Run Failure"; return 1; }

    _command_convert_fbs="${GALAXY_AGGREGATE_PIPELINE_BIN_DIR}/convert_sst_to_fbs ${_output_local_path}/output_media_doc_info"
    echo $_command_convert_fbs
    LoggerInfo $_command_convert_fbs
    nohup $_command_convert_fbs


    LoggerInfo "MrImageTextDetailBuilder Run Success"
    return 0

}

function FreshData()
{
    echo "put the hot data to "$HADOOP_HOT_DATA
    rm -f hot_people
    wget http://10.148.12.101:8000/wanghongqing/chenglinpeng/leview_movie/out/hot_people
    hadoop fs -put -f hot_people $HADOOP_HOT_DATA
    rm -f movie_all
    wget http://10.148.12.101:8000/wanghongqing/chenglinpeng/leview_movie/data/movie_all
    hadoop fs -put -f movie_all $HADOOP_HOT_DATA
    rm -f TVplay_all
    wget http://10.148.12.101:8000/wanghongqing/chenglinpeng/leview_movie/data/TVplay_all
    hadoop fs -put -f TVplay_all $HADOOP_HOT_DATA
    rm -f variety_all
    wget http://10.148.12.101:8000/wanghongqing/chenglinpeng/leview_movie/data/variety_all
    hadoop fs -put -f variety_all $HADOOP_HOT_DATA
    rm -f cartoon_all
    wget http://10.148.12.101:8000/wanghongqing/chenglinpeng/leview_movie/data/cartoon_all
    hadoop fs -put -f cartoon_all $HADOOP_HOT_DATA

    rm -f baidu_today_hotsearch.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/baidu_today_hotsearch.txt
    hadoop fs -put -f baidu_today_hotsearch.txt $HADOOP_HOT_DATA
    rm -f baidu_realtime_hot_search.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/baidu_realtime_hot_search.txt
    hadoop fs -put -f baidu_realtime_hot_search.txt $HADOOP_HOT_DATA
    rm -f qq_headline.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/qq_headline.txt
    hadoop fs -put -f qq_headline.txt $HADOOP_HOT_DATA
    rm -f ifeng_headline.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/ifeng_headline.txt
    hadoop fs -put -f ifeng_headline.txt $HADOOP_HOT_DATA
    rm -f sina_headline.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/sina_headline.txt
    hadoop fs -put -f sina_headline.txt $HADOOP_HOT_DATA
    rm -f sina_finance.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/sina_finance.txt
    hadoop fs -put -f sina_finance.txt $HADOOP_HOT_DATA
    rm -f ifeng_finance.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/ifeng_finance.txt
    hadoop fs -put -f ifeng_finance.txt $HADOOP_HOT_DATA
    rm -f hupu_sport.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/hupu_sport.txt
    hadoop fs -put -f hupu_sport.txt $HADOOP_HOT_DATA
    rm -f sina_sport.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/sina_sport.txt
    hadoop fs -put -f sina_sport.txt $HADOOP_HOT_DATA
    rm -f qq_sport.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/qq_sport.txt
    hadoop fs -put -f qq_sport.txt $HADOOP_HOT_DATA
    rm -f ifeng_ent.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/ifeng_ent.txt
    hadoop fs -put -f ifeng_ent.txt $HADOOP_HOT_DATA
    rm -f qq_ent.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/qq_ent.txt
    hadoop fs -put -f qq_ent.txt $HADOOP_HOT_DATA
    rm -f sina_ent.txt
    wget http://10.148.12.101:8000/wanghongqing/leview_news/data/sina_ent.txt
    hadoop fs -put -f sina_ent.txt $HADOOP_HOT_DATA

}

function MrImageTextPipelineRoutine()
{

    MrImageTextPipelineInit
    [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
    
    LoggerInfo "Run $COMMAND routine"

    case $COMMAND in
        latest)
            FreshData
            RunHBaseExtractionLatest
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; } 
            PullIndexData
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; } 
            RunImageTextIndexBuilderLatest
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            RunImageTextDetailBuilderLatest
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            ./transfer_data_inc2.sh
            ;;
        batch)
#FreshData
            RunHBaseExtraction
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; } 
            PullIndexData
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; } 
            RunImageTextIndexBuilder
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            RunImageTextDetailBuilder
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            ./transfer_data2.sh
            ;;
    esac

    MrImageTextPipelineClean
    return 0
}


function mainloop() {

    case $COMMAND in
        latest|adapter|batch|annotator|test)
            PIPELINE_LOGFILE=${GALAXY_AGGREGATE_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${LOGFILE_SUFFIX}.log
            mkdir -p ${GALAXY_AGGREGATE_PIPELINE_LOG_DIR}
            ;;
        clean)
            CLEAN_LOGFILE=${GALAXY_AGGREGATE_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${CURRENT_DATE}.log
            MrImageTextPipelineClean >>${CLEAN_LOGFILE}; return 0
            ;;
        *)
            LoggerError "Unknown Command $COMMAND"
            return 1
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


    MrImageTextPipelineRoutine >> ${PIPELINE_LOGFILE} 2>&1

    if [ $? -ne 0 ] && [ "X${ENABLE_ALERT}" = "Xtrue" ]; then
        LoggerError "${COMMAND} Run failed";
        rm -rf ${GALAXY_AGGREGATE_PIPELINE_PIDFILE}
#        MrImageTextPipelineAlert ${IMAGETEXT_PIPELINE_LOGFILE}
        return 1;
    fi
    rm -rf ${GALAXY_AGGREGATE_PIPELINE_PIDFILE}
    return 0;
}

mainloop $*
exit $?


