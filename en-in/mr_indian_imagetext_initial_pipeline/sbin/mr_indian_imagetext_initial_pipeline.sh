#!/bin/sh
cd `dirname $0`
source /etc/profile
#===============================================================================
#
# Copyright (c) 2015 Letv.com, Inc. All Rights Reserved
#
#
# File: sbin/mr_indian_imagetext_initial_pipeline.sh
# Author: Shang Huaiying(shanghuaiying@letv.com)
# Date: 2016/07/13
#
#===============================================================================
data_date=
input_path=
output_path='pipeline'

if [ $# -ge 3 ]
then
    if [ $# -ge 1 ]
    then
        data_date=$1
    fi
    if [ $# -ge 2 ]
    then
        input_path=$2
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

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_LIB_DIR=${IMAGETEXT_PIPELINE_HOME}/lib
IMAGETEXT_PIPELINE_BIN_DIR=${IMAGETEXT_PIPELINE_HOME}/bin
IMAGETEXT_PIPELINE_JAR_DIR=${IMAGETEXT_PIPELINE_HOME}/jar
IMAGETEXT_PIPELINE_CONF_DIR=${IMAGETEXT_PIPELINE_HOME}/conf


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

HADOOP_IMAGETEXT_DEDUP_DIR=/data/overseas_in/search/short_video/${input_path}
HADOOP_IMAGETEXT_FULL_DEDUP=
HADOOP_IMAGETEXT_INC=

HADOOP_IMAGETEXT_WORKING_DIR=/data/overseas_in/recommendation/pipeline/${output_path}
HADOOP_IMAGETEXT_DIFF_DIR=$HADOOP_IMAGETEXT_WORKING_DIR/${data_date}/diff

TEST_INPUT_COMPOSITE_DOC_PATH=

CATEGORY_RANK_FILE=data/dict/category_rank_info.dat
SVM_MODEL_PATH=${IMAGETEXT_PIPELINE_LIB_DIR}/model

COMMAND=build

IMAGETEXT_PIPELINE_REPO_BACKUP_MD5SUM=${IMAGETEXT_PIPELINE_REPO_BACKUP_DIR}/md5sum

LONG_VIDEO_PROCESSED_TIME=
SHORT_VIDEO_PROCESSED_TIME=

########################Must define for different pipeline############################

HBASE_COMPOSITEDOC_TABLE_NAME=IndiaTable
HBASE_CRAWL_DATA_HASH_TABLE_NAME=IndiaHashFilterTable

CONFIGURE_LANGUAGE_TYPE=en

######################################################################################


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
    mkdir -p ${IMAGETEXT_PIPELINE_REPO_BACKUP_DIR}
    mkdir -p ${IMAGETEXT_PIPELINE_HOME}/lib/{java,shell,model}
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

    input_hadoop_inc_file=${HADOOP_IMAGETEXT_DEDUP_DIR}/imagetext_${data_date}/_SUCCESS
    if ( HadoopFileSysExists $input_hadoop_inc_file ); then
        echo "the input exist"
    else
        LoggerError "The input file not exist!!!"
        return 1
    fi

    LoggerInfo "--------------------------------------------------------------------------------"
    return 0
}

function MrImageTextPipelineClean()
{
    LoggerInfo "ImageText Pipeline Cleaning"
    rm -rf ${IMAGETEXT_PIPELINE_PIDFILE}
}

function RunMD5HashFilter()
{
    export HADOOP_CLASSPATH=$HBASE_HOME/lib/*:classpath

    # get hash table from hbase
    #hadoop jar HBaseUtil.jar HBaseHashOutPut IndiaHashFilterTable hash /data/overseas_in/recommendation/pipeline/HBaseToHdfs/datatest
    _hadoop_filter_tmp_dir=$HADOOP_IMAGETEXT_WORKING_DIR/filter/
    HadoopFileSysRemoveDir -skipTrash $_hadoop_filter_tmp_dir
    _command="hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/HBaseUtil.jar HBaseHashOutputSequence   \
                         ${HBASE_CRAWL_DATA_HASH_TABLE_NAME} hash                                            \
                         $_hadoop_filter_tmp_dir                                              \ "
    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrReadDocHash Run Failure"; return 1; }
    LoggerInfo "MrDumpToHbash Run Success"

    # read the crawler data
     _image_text_path=${HADOOP_IMAGETEXT_FULL_DEDUP}
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full deduped image text not found."$_image_text_path
        return 1
    fi
    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')
    _output_hadoop_path=${HADOOP_IMAGETEXT_DIFF_DIR}
    HadoopFileSysRemoveDir -skipTrash ${_output_hadoop_path}
   
    _command=" ${IMAGETEXT_PIPELINE_BIN_DIR}/mr_crawl_hash_filter              \
        --auto_run                \
        --num_mapper=10            \
        --num_reducer=20              \
        --input_format=sequence        \
        --output_format=multi_text        \
        --enable_multi_mapper_output=true \
        --hdfs_input_paths=$_hadoop_filter_tmp_dir,$_input_hadoop_path        \
        --hdfs_output_dir=$_output_hadoop_path        \
        --lib_jars=${IMAGETEXT_PIPELINE_LIB_DIR}/java/custom_format_1_1_2.jar \
        --hdfs_bin_dir=${HADOOP_BINARY_DIR}        \
        --hadoop_binary=hadoop    \
        --compatible_mod=false        \
        --compress_map_output=false       \
        --compress_mapper_out_value=false \
        --fileoutput_compress=false       \
        --shuffle_input_buffer_percent=0.5\
      "
    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrCrawlerHashFilter Run Failure"; return 1; }

    LoggerInfo "MrCrawlerHashFilter Run Success"
 

}

function RunImageTextAdapter()
{
    _input_hadoop_path=
    _output_hadoop_path=
     
    _image_text_path=${HADOOP_IMAGETEXT_FULL_DEDUP}
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full deduped image text not found."
        return 1
    fi

    _image_text_path=${HADOOP_IMAGETEXT_INC}
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')
    _output_hadoop_path=${HADOOP_ADAPTER_IMAGETEXT_WORKING_DIR}
    HadoopFileSysRemoveDir -skipTrash ${_output_hadoop_path}


    _command="                                                                                  \
      ${IMAGETEXT_PIPELINE_BIN_DIR}/mr_crawl_log_convert_main                                                      \
            --auto_run                                                                          \
            --num_mapper=${MAPRED_NUM_MAPPER}                                                   \
            --num_reducer=100                                                 \
            --input_format=kv_text                                                             \
            --output_format=text                                                                \
            --hdfs_input_paths=$_input_hadoop_path                                              \
            --hdfs_output_dir=$_output_hadoop_path                                              \
            --enable_multi_mapper_output=false                                                  \
            --hdfs_bin_dir=${HADOOP_BINARY_DIR}                                                 \
            --hadoop_binary=hadoop                                                              \
            --lib_jars=${IMAGETEXT_PIPELINE_LIB_DIR}/java/custom_format_1_1_2.jar                                                \
            --compatible_mod=false                                                              \
            --compress_map_output=false                                                         \
            --compress_mapper_out_value=false                                                   \
            --fileoutput_compress=false                                                         \
            --enable_accept=false                                                               \
             --uploading_files=${IMAGETEXT_PIPELINE_CONF_DIR}                                    \
            --converter_type=CrawlDocumentConverter                                             \
            --domain_info=conf/domain_info_domain.conf                                           \
            --prefix_info=conf/domain_info_url_prefix.conf                                      \
            --language_type=${CONFIGURE_LANGUAGE_TYPE}                                          \
    "

    echo $_commend
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextAdapter Run Failure"; return 1; }

    LoggerInfo "MrImageTextAdapter Run Success"
    return 0

}

function RunImageTextNLP()
{
    _input_hadoop_path=
    _output_hadoop_path=

    _image_text_path=${HADOOP_ADAPTER_IMAGETEXT_OUTPUT}
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full imagetext adapter output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')
    _output_hadoop_path=${HADOOP_NLP_IMAGETEXT_WORKING_DIR}
    HadoopFileSysRemoveDir -skipTrash ${_output_hadoop_path}


    _command="                                                                                  \
            hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar DocumentProcess                   \
            ${_input_hadoop_path} ${_output_hadoop_path}                                        \
            ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/commons-codec-1.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/JavaNLPWrapper.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-corenlp-3.4.1-models.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/stanford-srparser-2014-08-28-models.jar\
    "

    echo $_commend
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextNLP Run Failure"; return 1; }

    LoggerInfo "MrImageTextNLP Run Success"
    return 0

}


function RunImageTextDumpToHBase()
{
    export HADOOP_CLASSPATH=$HBASE_HOME/lib/*:classpath
    _input_hadoop_path=

    _image_text_path=${HADOOP_HANDLER_IMAGETEXT_WORKING_DIR}/handler_compositedoc
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full imagetext handler output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')
    #HadoopFileSysRemoveDir -skipTrash ${_output_hadoop_path}


    _command="hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/HBaseUtil.jar DocumentHBaseMR \
                         $_input_hadoop_path                                         \
                         $HBASE_COMPOSITEDOC_TABLE_NAME                              \
    "

    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrDumpToHBash Run Failure"; return 1; }

    LoggerInfo "MrDumpToHbash Run Success"

    
    _input_hadoop_path=
    _image_text_path=${HADOOP_IMAGETEXT_DIFF_DIR}/hash_value
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full imagetext handler output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')


    _command="hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/HBaseUtil.jar HBaseHashInPut  \
                         $_input_hadoop_path                                         \
                         ${HBASE_CRAWL_DATA_HASH_TABLE_NAME} hash                    \
    "
    echo $_command
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrDumpURLHashToHBash Run Failure"; return 1; }

    LoggerInfo "MrDumpURLHashToHbash Run Success"

    return 0
}

function RunMRHandler()
{
    _input_hadoop_path=
    _output_hadoop_path=

    _image_text_path=${HADOOP_NLP_IMAGETEXT_OUTPUT}
    if ( HadoopFileSysExists $_image_text_path ); then
        _input_hadoop_path="$_input_hadoop_path $_image_text_path"
    else
        LoggerError "Full imagetext NLP output not found."
        return 1
    fi

    [ -n "${_input_hadoop_path}" ] || { LoggerError "Empty Input"; return 1; }

    _input_hadoop_path=$(echo $_input_hadoop_path | sed -e 's/ /,/g')
    _output_hadoop_path=${HADOOP_HANDLER_IMAGETEXT_WORKING_DIR}
    HadoopFileSysRemoveDir -skipTrash ${_output_hadoop_path}


    _command="                                                                                  \
         ${IMAGETEXT_PIPELINE_BIN_DIR}/mr_indian_handler_main \
             --auto_run \
             --num_mapper=${MAPRED_NUM_MAPPER} \
             --num_reducer=${MAPRED_NUM_REDUCER} \
             --hdfs_server=hadoopNN1.com \
             --hdfs_host=hdfs://us-cluster \
             --hdfs_port=9000 \
             --input_format=text \
             --output_format=multi_text \
             --compatible_mod=false \
             --compress_map_output=false \
             --compress_mapper_out_value=false \
             --fileoutput_compress=false \
             --shuffle_input_buffer_percent=0.5 \
             --hdfs_bin_dir=${HADOOP_BINARY_DIR} \
             --hdfs_input_paths=$_input_hadoop_path \
             --hdfs_output_dir=$_output_hadoop_path \
             --hadoop_binary=/usr/local/hadoop/bin/hadoop \
             --lib_jars=${IMAGETEXT_PIPELINE_LIB_DIR}/java/custom_format_1_1_2.jar \
             --composite_doc_output=handler_compositedoc \
             --uploading_files=${IMAGETEXT_PIPELINE_CONF_DIR},${IMAGETEXT_PIPELINE_LIB_DIR}/model \
             --enable_multi_mapper_output=true \
             "
    #normalize
    handlers="IndInlinkBasedNormalizeHandler"
    _command="$_command --ind_inlink_based_normalize_config_path=conf/normalized_inlink.conf"

#handlers="$handlers,IndCategoryInfoNormalizeHandler"
    _command="$_command --category_info_normalize_config_path=conf/normalized_category.conf"

#handlers="$handlers,IndBreadCrumbsNormalizeHandler"
    _command="$_command --ind_bread_crumbs_normalize_config_path=conf/normalized_crumbs.conf"
    _command="$_command --ind_prefix_based_normalize_config_path=conf/normalized_url_prefix.conf"

    handlers="SimpleMultipleClassifyHandler,IndInlinkBasedNormalizeHandler"
    _command="$_command --simple_multiple_model_configuration_file=model/Entertainment_dic.key,model/Entertainment_tms.model,Entertainment:model/sports_dic.key,model/sports_tms.model,Sports:model/world_dic.key,model/world_tms.model,World:model/auto_dic.key,model/auto_tms.model,Autos:model/Education_dic.key,model/Education_tms.model,Education:model/Lifestyle_dic.key,model/Lifestyle_tms.model,Lifestyle --use_classify_segmentor=false"

#handlers="$handlers,INDFeatureExtractorHandler"
    _command="$_command --category_expand_file_path_ind=conf/category_expand.conf"

    _command="$_command --handlers=$handlers"


    echo $_commend
    LoggerInfo $_command
    nohup $_command
    [ $? -eq 0 ] || { LoggerError "MrImageTextHandler Run Failure"; return 1; }

    LoggerInfo "MrImageHandler Run Success"
    return 0

}


function MrImageTextPipelineRoutine()
{

    MrImageTextPipelineInit
    [ $? -eq 0 ] || { MrImageTextPipelineClean; return 11; }

    LoggerInfo "Run $COMMAND routine"

    case $COMMAND in
        build)
            
            _hadoop_date=${data_date}
            if ( HadoopFileSysExists ${HADOOP_IMAGETEXT_DEDUP_DIR}/imagetext_${_hadoop_date}/_SUCCESS ); then
                HADOOP_IMAGETEXT_FULL_DEDUP=${HADOOP_IMAGETEXT_DEDUP_DIR}/imagetext_${_hadoop_date}/part*
            fi
            HADOOP_IMAGETEXT_INC=
            HADOOP_ADAPTER_IMAGETEXT_WORKING_DIR=${HADOOP_IMAGETEXT_WORKING_DIR}/adapter_output/${_hadoop_date}

            MAPRED_NUM_MAPPER=${MAPRED_ADAPTER_NUM_MAPPER}
            MAPRED_NUM_REDUCER=${MAPRED_ADAPTER_NUM_REDUCER}

            echo "Crawler data:"${HADOOP_IMAGETEXT_FULL_DEDUP}
            RunMD5HashFilter
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            HADOOP_IMAGETEXT_FULL_DEDUP=${HADOOP_IMAGETEXT_DIFF_DIR}/input
            echo "Adapter output:"${HADOOP_ADAPTER_IMAGETEXT_WORKING_DIR}
            RunImageTextAdapter
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }

            if ( HadoopFileSysExists ${HADOOP_IMAGETEXT_WORKING_DIR}/adapter_output/${_hadoop_date}/_SUCCESS ); then
                HADOOP_ADAPTER_IMAGETEXT_OUTPUT=${HADOOP_IMAGETEXT_WORKING_DIR}/adapter_output/${_hadoop_date}/part*
            fi
            HADOOP_NLP_IMAGETEXT_WORKING_DIR=${HADOOP_IMAGETEXT_WORKING_DIR}/javamr_output1/${_hadoop_date}
            
            echo "NLP input:"${HADOOP_ADAPTER_IMAGETEXT_OUTPUT}
            echo "NLP output:"${HADOOP_NLP_IMAGETEXT_WORKING_DIR}
            RunImageTextNLP
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }

            if ( HadoopFileSysExists ${HADOOP_IMAGETEXT_WORKING_DIR}/javamr_output1/${_hadoop_date}/_SUCCESS ); then
                HADOOP_NLP_IMAGETEXT_OUTPUT=${HADOOP_IMAGETEXT_WORKING_DIR}/javamr_output1/${_hadoop_date}/part*
            fi
            HADOOP_HANDLER_IMAGETEXT_WORKING_DIR=${HADOOP_IMAGETEXT_WORKING_DIR}/handler_output/${_hadoop_date}
            
            echo "Handler input:"${HADOOP_NLP_IMAGETEXT_OUTPUT}
            echo "Handler output:"${HADOOP_HANDLER_IMAGETEXT_WORKING_DIR}
            RunMRHandler
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }

            RunImageTextDumpToHBase
            [ $? -eq 0 ] || { MrImageTextPipelineClean; return 1; }
            ;;
    esac

    MrImageTextPipelineClean
    return 0
}


function mainloop() {

    COMMAND=build
    if [ $# -gt 4 ]; then
        COMMAND=$4
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


    ENABLE_ALERT="true"
    MrImageTextPipelineRoutine >> ${IMAGETEXT_PIPELINE_LOGFILE} 2>&1

    if [ $? -ne 0 ] && [ "X${ENABLE_ALERT}" = "Xtrue" ]; then
        LoggerError "${COMMAND} Run failed";
#        MrImageTextPipelineAlert ${IMAGETEXT_PIPELINE_LOGFILE}
        return 1;
    fi

    return 0;
}

mainloop $*
exit $?


