#!/bin/bash

cd `dirname $0`
source /etc/profile

remote_ip=10.121.145.29
remote_folder=/home/rec/data/pipeline/ml/lightlda

if [ -f occupy.lock ]
then
    echo "Already an instance run!"
    exit 1
else
    touch occupy.lock
fi

if [ $# -ge 2 ]
then
  pipeline_dir=$1
  hadoop_dir=$2
else
  echo "argv wrong! END"
  rm -f occupy.lock
  exit 1
fi

IMAGETEXT_PIPELINE_JAR_DIR=$pipeline_dir/jar
_hadoop_forwardindex_output=$hadoop_dir/forward_index/
_hadoop_aggregate_output=$hadoop_dir/aggregate_output/
IMAGETEXT_PIPELINE_DATA_DIR=$pipeline_dir/data
_hadoop_doc_topic=$hadoop_dir/aggregate_result/
 

function HadoopJobStart()
{   
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

}

function RemoteProcess()
{
    hadoop fs -getmerge $_hadoop_forwardindex_output  forward_index.dat
    scp  forward_index.dat rec@$remote_ip:$remote_folder/input
    (ssh rec@$remote_ip "cd $remote_folder;  ./run_local.sh > log.txt 2>&1 ") & 
    [ $? -eq 0 ] || { LoggerError "Remote SSH lightlda Run Failure"; return 2; }

    # wait the backend service
    wait
    echo "finish the async!"

    scp rec@$remote_ip:$remote_folder/docid_topic lda_topic
    scp rec@$remote_ip:$remote_folder/lda_similarity.txt lda_similarity.txt
    if [ ! -f ./lda_topic ]
    then
        echo "get lda_topic failed!"
        return 3
    fi

    # build the related doc
    cmd="$pipeline_dir/bin/text_to_obj_sst_transformer_main \
        --input_file_path=./lda_similarity.txt \
        --output_file_path=./related_docs.sst \
        --output_sst=true \
        --beishu=1000 \
    "
    echo $cmd
    $cmd


    rm -f forward_index.dat
    hadoop fs -put -f lda_topic $_hadoop_doc_topic
    rm -f lda_topic
}


#HadoopJobStart
[ $? -eq 0 ] || { echo "Hadoopjob Run Failure"; rm -rf occupy.lock; exit $?; } 
RemoteProcess
[ $? -eq 0 ] || { echo "Remotejob Run Failure"; rm -rf occupy.lock; exit $?; }

echo "LDA Run successed!"
rm -rf occupy.lock

