#!/bin/bash

cd `dirname $0`
source /etc/profile

remote_ip=10.121.145.29
remote_folder=/home/rec/data/pipeline/ml/gensim_doc2vec


if [ -f occupy.lock ]
then
    echo "Related is already run! END"
    exit 1
else
    touch occupy.lock
fi

if [ $# -ge 2 ]
then
  pipeline_dir=$1
  hadoop_dir=$2
else
  rm -f occupy.lock
  exit 1
fi


IMAGETEXT_PIPELINE_JAR_DIR=$pipeline_dir/jar
_hadoop_forwardindex_output=$hadoop_dir/forward_index/
_hadoop_aggregate_output=$hadoop_dir/aggregate_output/
IMAGETEXT_PIPELINE_DATA_DIR=$pipeline_dir/data
_hadoop_doc_topic=$hadoop_dir/aggregate_result/
_hadoop_invertindex_output=$hadoop_dir/invert_index/
 

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
}


function RelatedJob()
{
    forward_index=$hadoop_dir/forward_index/
    forward_index_copy=$hadoop_dir/forward_index_copy/
    related_output=$hadoop_dir/related

    hadoop_binary=hadoop
    hdfs_bin_dir=/data/overseas_in/recommendation/pipeline/tmp/bin

    rm -f invert_index.data
    hadoop fs -getmerge $_hadoop_invertindex_output invert_index.data

    cmd="$pipeline_dir/bin/related_mapreduce
        --auto_run
        --num_mapper=100
        --num_reducer=0
        --input_format=text
        --output_format=text
        --hdfs_output_dir=$related_output
        --hdfs_input_paths=$forward_index
        --enable_multi_mapper_output=false
        --hdfs_bin_dir=$hdfs_bin_dir
        --hadoop_binary=$hadoop_binary
        --lib_jars=$pipeline_dir/lib/java/custom_format_1_1_2.jar
        --uploading_files=./invert_index.data
        --compatible_mod=false
        --compress_map_output=false
        --compress_mapper_out_value=false
        --fileoutput_compress=false
        --shuffle_input_buffer_percent=0.5
     "
    echo $cmd
    $cmd
    
    rm -f related_docs.dat
    hadoop fs -getmerge $related_output related_docs.dat

    cat related_docs.dat | python ./GetRelatedText.py > related_docs.txt 
    cat related_docs.dat | python ./GetClusterText.py 0.95 > cluster1.txt
    cat related_docs.dat | python ./GetClusterText.py 0.9 > cluster2.txt
    awk -F '\t' '{print $1"\tweight\t"$2" "$3 }' related_docs.dat > doc_weight.txt

    cmd="$pipeline_dir/bin/text_to_obj_sst_transformer_main \
        --input_file_path=./related_docs.txt \
        --output_file_path=./related_docs.sst \
        --output_sst=true \
        --beishu=1000 \
    "
    echo $cmd
    $cmd
    
    $pipeline_dir/bin/document_cluster_int_main ./cluster1.txt ./cluster1_res.txt cluster1
    $pipeline_dir/bin/document_cluster_int_main ./cluster2.txt ./cluster2_res.txt cluster2

    hadoop fs -put -f ./doc_weight.txt $_hadoop_doc_topic
    hadoop fs -put -f ./cluster1_res.txt $_hadoop_doc_topic
    hadoop fs -put -f ./cluster2_res.txt $_hadoop_doc_topic

}


#HadoopJobStart
[ $? -eq 0 ] || { echo "Hadoopjob Run Failure"; rm -rf occupy.lock; exit $?; } 
RelatedJob
[ $? -eq 0 ] || { echo "Remotejob Run Failure"; rm -rf occupy.lock; exit $?; }

echo "Run related job successed!"
sleep 20h
rm -rf occupy.lock
