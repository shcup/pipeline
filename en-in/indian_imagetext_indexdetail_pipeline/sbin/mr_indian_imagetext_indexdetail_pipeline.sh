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

if [ $# -ge 1 ]
then
    if [ $# -ge 1 ]
    then
        pipeline=$1
    fi
    if [ $# -ge 2 ]
    then
        no_build_index=$2
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

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_LIB_DIR=${IMAGETEXT_PIPELINE_HOME}/lib
IMAGETEXT_PIPELINE_BIN_DIR=${IMAGETEXT_PIPELINE_HOME}/bin
IMAGETEXT_PIPELINE_JAR_DIR=${IMAGETEXT_PIPELINE_HOME}/jar
IMAGETEXT_PIPELINE_CONF_DIR=${IMAGETEXT_PIPELINE_HOME}/conf
IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/data

IMAGETEXT_PIPELINE_LOGFILE=
IMAGETEXT_PIPELINE_PIDFILE=

CURRENT_DATE=$(date +%Y%m%d)
CURRENT_HOUR=$(date +%Y%m%d%H)
CURRENT_TIME=$(date +%Y%m%d%H%M%S)

LOGFILE_SUFFIX=$(date "+%Y%m%d_%H")

declare -A STATIC_HANDLER_CONF

source ${IMAGETEXT_PIPELINE_HOME}/conf/mr_imagetext_pipeline.conf
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/logger.sh
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/fs.sh
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/hdfs.sh
source ${IMAGETEXT_PIPELINE_LIB_DIR}/shell/mr_imagetext_pipeline_routines.sh

MAPRED_INPUT_PATH=
MAPRED_OUTPUT_PATH=
MAPRED_NUM_MAPPER=
MAPRED_NUM_REDUCER=

HADOOP_BINARY_DIR=/data/overseas_in/recommendation/pipeline/tmp/bin

HADOOP_IMAGETEXT_DEDUP_DIR=/data/overseas_in/search/short_video/full
HADOOP_IMAGETEXT_FULL_DEDUP=
HADOOP_IMAGETEXT_INC=

HADOOP_IMAGETEXT_WORKING_DIR=/data/overseas_in/recommendation/pipeline/${data_path}
HADOOP_IMAGETEXT_INDEX_DIR=/data/overseas_in/recommendation/index_builder/${pipeline}/index_data
HADOOP_IMAGETEXT_INDEXBUILDER_DIR=/data/overseas_in/recommendation/index_builder/${pipeline}

TEST_INPUT_COMPOSITE_DOC_PATH=

CATEGORY_RANK_FILE=data/dict/category_rank_info.dat

COMMAND=build

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

    mkdir -p ${IMAGETEXT_PIPELINE_HOME}/{job,log,repo,status,temp,lib}
    mkdir -p ${IMAGETEXT_PIPELINE_LOG_DIR}/{info,warn,error,debug}
    mkdir -p ${IMAGETEXT_PIPELINE_BUILD_DIR}/{input,output,stat}
    mkdir -p ${IMAGETEXT_PIPELINE_DATA_DIR}/input/{index_builder,detail_builder}
    mkdir -p ${IMAGETEXT_PIPELINE_DATA_DIR}/output/{index_builder,detail_builder}
    mkdir -p ${IMAGETEXT_PIPELINE_REPO_BACKUP_DIR}
    mkdir -p ${IMAGETEXT_PIPELINE_TEST_DIR}/data/{input,output}

    HadoopFileSysMakeDir ${HADOOP_BINARY_DIR}
#    HadoopFileSysMakeDir ${HADOOP_IMAGETEXT_PIPELINE_GENERATOR_DIR}
#    HadoopFileSysMakeDir ${HADOOP_IMAGETEXT_PIPELINE_ANNOTATOR_DIR}

    IMAGETEXT_PIPELINE_PIDFILE=${IMAGETEXT_PIPELINE_STATUS_DIR}/mr_$COMMAND.pid
    if [ -s ${IMAGETEXT_PIPELINE_PIDFILE} ] && [ -d /proc/$(cat ${IMAGETEXT_PIPELINE_PIDFILE} 2>/dev/null)/cwd ]; then
        LoggerInfo "There's already a mr_$COMMAND pipeline running, quit!"
        exit 5
    else
        echo $$ > ${IMAGETEXT_PIPELINE_PIDFILE}
        [ $? -eq 0 ] || { LoggerError "Creating pid file failed, quit!"; return 1; }
    fi

    LoggerInfo "--------------------------------------------------------------------------------"
    return 0
}

function MrImageTextPipelineClean()
{
    LoggerInfo "ImageText Pipeline Cleaning"
    rm -rf ${IMAGETEXT_PIPELINE_PIDFILE}
}

_input_local_path=${IMAGETEXT_PIPELINE_HOME}/data/input/
function PullIndexData()
{
    _input_hadoop_path=
    _output_hadoop_path=
     
    _image_text_path=${HADOOP_IMAGETEXT_INDEX_DIR}/part*
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "imagetext handler output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty hadoop Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')

    rm -f ${_input_local_path}/hdfs_data_input
    hadoop fs -text ${_input_hadoop_path} > ${_input_local_path}/hdfs_data_input


}

function RunImageTextIndexBuilder()
{
    _output_local_path=${IMAGETEXT_PIPELINE_HOME}/data/output/index_builder


    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

    _command="                                                                                  \
    $IMAGETEXT_PIPELINE_BIN_DIR/recommendation_index_builder_main \
    --input_full_composite_doc_path=${_input_local_path}/hdfs_data_input \
    --input_fresh_composite_doc_paths= \
    --output_composite_doc_path=${_output_local_path}/output_composite_doc \
    --repository_dir=${IMAGETEXT_PIPELINE_HOME}/data/output/index_builder  \
    --done_path=${_output_local_path}/done \
    --index_builders=FeatureIndexBuilder \
    --min_final_doc_count=10 \
    --feature_rec_min_inverted_list_size=20 \
    --feature_rec_product_indexes=10:indian_imagetext_feature_rec \
    --feature_rec_score_computer=INDIndexScoreComputer \
    --feature_rec_index_scoring_conf_path=${IMAGETEXT_PIPELINE_CONF_DIR}/index_scoring.conf \
    --feature_rec_indexfile_suffix=test \
    --keep_lower_for_index_key=true \
    --v=0 \
    --dump_data_for_statistic_file=statistic_file \
        "

    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextIndexBuilder Run Failure"; return 1; }

    LoggerInfo "MrImageTextIndexBuilder Run Success"
    return 0

}

function RunImageTextDetailBuilder()
{
   _output_local_path=${IMAGETEXT_PIPELINE_HOME}/data/output/detail_builder

    [ -n "${_input_local_path}" ] || { LoggerError "Empty local Input"; return 1; }
    [ -d "${_output_local_path}" ] || { mkdir -p ${_output_local_path}; }

    _command="                                                                                  \
    ${IMAGETEXT_PIPELINE_BIN_DIR}/recommendation_detail_builder_main \
    --input_composite_doc_path=${_input_local_path}/hdfs_data_input \
    --output_detail_path=${_output_local_path}/output_detail \
    --output_media_doc_info_path=${_output_local_path}/output_media_doc_info \
    --done_path=${_output_local_path}/done \
    --detail_data_adapter=ResultDocInfoAdapter \
    --v=0 \
    "

    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextDetailBuilder Run Failure"; return 1; }

    _command_convert_fbs="${IMAGETEXT_PIPELINE_BIN_DIR}/convert_sst_to_fbs ${_output_local_path}/output_media_doc_info"
    echo $_command_convert_fbs
    LoggerInfo $_command_convert_fbs
    nohup $_command_convert_fbs

    LoggerInfo "MrImageTextDetailBuilder Run Success"
    return 0

}

function RunBatchAggregateProcess()
{
    _input_hadoop_path=
    _output_hadoop_path=
    _hadoop_aggregate_input=

   # collect the aggregate data
    export HADOOP_CLASSPATH=$HBASE_HOME/lib/*:classpath
    _hadoop_aggregate_output=/data/overseas_in/recommendation/index_builder/$pipeline/aggregate_output/  
    hadoop fs -rm -r -skipTrash $_hadoop_aggregate_output
    _command="hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/HBaseUtil.jar HBaseWriteMR IndiaTable \
                         $_hadoop_aggregate_output 180                                   \
                         ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/commons-codec-1.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar             
    "
    echo $_command
    LoggerInfo $_command
   
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "Index data input collection Run Failure"; return 1; }

    LoggerInfo "Index data input collection Run Success"

    # forward index and invert index
    _hadoop_forwardindex_output=/data/overseas_in/recommendation/index_builder/$pipeline/forward_index
    _hadoop_invertindex_output=/data/overseas_in/recommendation/index_builder/$pipeline/invert_index
    hadoop fs -rm -r -skipTrash $_hadoop_forwardindex_output
    _command="                                                                                  \
             hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar ForwardIndexBuilderMapReduce     \
             ${_hadoop_aggregate_output}  \
             ${_hadoop_forwardindex_output}  \
             ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/commons-codec-1.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/JavaNLPWrapper.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1-models.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-srparser-2014-08-28-models.jar"
    echo $_command
    nohup $_command
    [ $? -eq 0 ] || { echo "Forward index Run Failure"; return 1; }
    echo "Forward indexe Run Success"

    hadoop fs -rm -r -skipTrash $_hadoop_invertindex_output
    _command="
              hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar InvertIndexBuilderMapReduce      \
             ${_hadoop_aggregate_output}  \
             ${_hadoop_invertindex_output}  \
             ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/commons-codec-1.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/JavaNLPWrapper.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1-models.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-srparser-2014-08-28-models.jar"
    echo $_command
    nohup $_command
    [ $? -eq 0 ] || { echo "Inverted index Run Failure"; return 1; }
    echo "Inverted indexe Run Success"

    # articles get from hadoop
    _hadoop_articles_output=/data/overseas_in/recommendation/index_builder/$pipeline/articles
    hadoop fs -rm -r -skipTrash $_hadoop_articles_output
    _command="
            hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar MRDoc2VecInputGenerator ${_hadoop_aggregate_output} $_hadoop_articles_output ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar
    "
    echo $_command
    nohup $_command
    [ $? -eq 0 ] || { echo "Articles Run Failure"; return 1; }
    echo "Articles Run Success"



    # run the aggregation part in parallel
    _hadoop_doc_topic=/data/overseas_in/recommendation/index_builder/$pipeline/aggregate_result
    hadoop fs -mkdir $_hadoop_doc_topic
    echo `ls $IMAGETEXT_PIPELINE_HOME |grep ^aggregate_`
    for x in `ls $IMAGETEXT_PIPELINE_HOME |grep ^aggregate_`
    do
      echo $x
      cd $IMAGETEXT_PIPELINE_HOME/$x
      AGGREGATE_PIPELINE_LOGFILE=${IMAGETEXT_PIPELINE_LOG_DIR}/"Aggregate_"${x}_${LOGFILE_SUFFIX}.log
      _command="./run.sh ${IMAGETEXT_PIPELINE_HOME} ${HADOOP_IMAGETEXT_INDEXBUILDER_DIR} >> $AGGREGATE_PIPELINE_LOGFILE  2>&1 &"
      echo $_command
      nohup ./run.sh ${IMAGETEXT_PIPELINE_HOME} ${HADOOP_IMAGETEXT_INDEXBUILDER_DIR} >> $AGGREGATE_PIPELINE_LOGFILE  2>&1 &
      cd $IMAGETEXT_PIPELINE_HOME/sbin
    done

    # judge whether to build the index and detail
    LoggerInfo "Judge whether to build the index and detail"
    index_data_time=`hadoop fs -ls ${HADOOP_IMAGETEXT_INDEX_DIR}/_SUCCESS | awk '{print $6" "$7}'`
    index_data_timestamp=`date -d "$index_data_time" +%s`
    now_timestamp=`date +%s`
    LoggerInfo "index data time:"$index_data_time", index data timestamp:"$index_data_timestamp", now timestamp:"$now_timestamp
    latency_diff=`expr $now_timestamp - ${index_data_timestamp}`
    if [ $latency_diff -gt 7200 ]
    then
        LoggerInfo "Index obsolete, to build the index!!!"
    else
        LoggerInfo "Index fresh, exit!!!"
        return 10
    fi

    # merge the aggregation part result
    _command="
      ${IMAGETEXT_PIPELINE_BIN_DIR}/mr_aggregate_result_merge \
          --auto_run \
          --num_mapper=30 \
          --num_reducer=30 \
          --input_format=kv_text \
          --output_format=text \
          --hdfs_input_paths=$_hadoop_aggregate_output,$_hadoop_doc_topic \
          --hdfs_output_dir=$HADOOP_IMAGETEXT_INDEX_DIR \
          --enable_multi_mapper_output=false \
          --hdfs_bin_dir=${HADOOP_BINARY_DIR} \
          --hadoop_binary=hadoop \
          --lib_jars=${IMAGETEXT_PIPELINE_LIB_DIR}/java/custom_format_1_1_2.jar \
          --compatible_mod=false \
          --compress_map_output=false \
          --compress_mapper_out_value=false \
          --fileoutput_compress=false \
    " 
    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "Aggregation result merge Run Failure"; return 1; }
    LoggerInfo "Aggregation result merge Run Success"

}


function MrImageTextPipelineRoutine()
{

    MrImageTextPipelineInit
    [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }

    LoggerInfo "Run $COMMAND routine"

    case $COMMAND in
        build)
            RunBatchAggregateProcess
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
 
            _hadoop_date=${data_date}
#            if ( HadoopFileSysExists ${HADOOP_IMAGETEXT_WORKING_DIR}/handler_output/${data_date}/_SUCCESS ); then
#                HADOOP_HANDLER_IMAGETEXT_OUTPUT=${HADOOP_IMAGETEXT_WORKING_DIR}/handler_output/${data_date}/handler_compositedoc/part*
#            fi
#            echo "index_builder data in HDFS:"${HADOOP_HANDLER_IMAGETEXT_OUTPUT}
#
#            HADOOP_INDEX_IMAGETEXT_WORKING_DIR=${HADOOP_IMAGETEXT_WORKING_DIR}/index_output/${data_date}
#
            MAPRED_NUM_MAPPER=${MAPRED_ADAPTER_NUM_MAPPER}
            MAPRED_NUM_REDUCER=${MAPRED_ADAPTER_NUM_REDUCER}
            PullIndexData

            RunImageTextIndexBuilder
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }

#            if ( HadoopFileSysExists ${HADOOP_IMAGETEXT_WORKING_DIR}/handler_output/${data_date}/_SUCCESS ); then
#                HADOOP_HANDLER_IMAGETEXT_OUTPUT=${HADOOP_IMAGETEXT_WORKING_DIR}/handler_output/${data_date}/handler_compositedoc/part*
#            fi
#            echo "detail_builder data in HDFS:"${HADOOP_HANDLER_IMAGETEXT_OUTPUT}
#
#            HADOOP_DETAIL_IMAGETEXT_WORKING_DIR=${HADOOP_IMAGETEXT_WORKING_DIR}/detail_output/${data_date}

            RunImageTextDetailBuilder
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }                        
            ;;
    esac

    MrImageTextPipelineClean
    return 0
}


function mainloop() {

    COMMAND=build
    if [ $# -gt 3 ]; then
        COMMAND=$3
    fi

    shift 1

    case $COMMAND in
        build|adapter|generator|annotator|test)
            IMAGETEXT_PIPELINE_LOGFILE=${IMAGETEXT_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${LOGFILE_SUFFIX}.log
            ;;
        clean)
            CLEAN_LOGFILE=${IMAGETEXT_PIPELINE_LOG_DIR}/$(basename $0)_${COMMAND}_${CURRENT_DATE}.log
            MrImageTextPipelineClean >>${CLEAN_LOGFILE}; return 0
            ;;
        *)
            echo "Unknown Command $COMMAND"
            MrImageTextPipelineUsage; return 1
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
                MrImageTextPipelineUsage
                return 1
                ;;
        esac
    done

    shift $[$OPTIND-1]

    MrImageTextPipelineRoutine >> ${IMAGETEXT_PIPELINE_LOGFILE} 2>&1

    if [ $? -ne 0 ] && [ "X${ENABLE_ALERT}" = "Xtrue" ]; then
        LoggerError "${COMMAND} Run failed";
        rm -rf ${IMAGETEXT_PIPELINE_PIDFILE}
#        MrImageTextPipelineAlert ${IMAGETEXT_PIPELINE_LOGFILE}
        return 1;
    fi
    sh -x ./transfer_data.sh
    #scp ../data/output/detail_builder/output_media_doc_info.fbs rec@$remote_ip:~/data/recommendation/topnews1/engine/dynamic_data/media_doc_info.sst.fbs
    #scp ../data/output/detail_builder/output_media_doc_info rec@$remote_ip:~/data/recommendation/topnews1/engine/dynamic_data/media_doc_info.sst
    #scp ../data/output/detail_builder/output_detail rec@$remote_ip:~/data/recommendation/topnews1/detail/data/output_detail    
    #scp ../data/output/index_builder/indian_imagetext_feature_rec_test.sst rec@$remote_ip:~/data/recommendation/topnews1/engine/dynamic_data/indian_imagetext_feature_rec_test.sst
    #scp ../data/output/index_builder/indian_imagetext_feature_rec_bin_test.fbs rec@$remote_ip:~/data/recommendation/topnews1/engine/dynamic_data/indian_imagetext_feature_rec_test.sst.fbs
    #scp ../data/aggregate_related/related_docs.sst rec@$remote_ip:~/data/recommendation/topnews1/engine/dynamic_data/related_docs.sst

    rm -rf ${IMAGETEXT_PIPELINE_PIDFILE}
    return 0;
}

mainloop $*
exit $?


