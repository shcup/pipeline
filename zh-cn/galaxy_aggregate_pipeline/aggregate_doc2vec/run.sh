#!/bin/bash

cd `dirname $0`
source /etc/profile

remote_ip=10.121.145.29
remote_folder=/home/rec/data/pipeline/ml/gensim_doc2vec

if [ -f occupy.lock ]
then
    echo "doc2vec already run! END"
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
_hadoop_aggregate_output=$hadoop_dir/aggregate_output/
IMAGETEXT_PIPELINE_DATA_DIR=$pipeline_dir/data
_hadoop_doc_topic=$hadoop_dir/aggregate_result/
_hadoop_articles_output=$hadoop_dir/articles/
 

function HadoopJobStart()
{   
    hadoop fs -rm -r -skipTrash $_hadoop_articles_output
    _command="
            hadoop jar ${IMAGETEXT_PIPELINE_JAR_DIR}/DPMR.jar MRDoc2VecInputGenerator ${_hadoop_aggregate_output} $_hadoop_articles_output ${IMAGETEXT_PIPELINE_JAR_DIR}/HadoopCompositeDoc.jar,${IMAGETEXT_PIPELINE_JAR_DIR}/libthrift-0.9.3.jar
    "
    echo $_command
    echo $_command
    nohup $_command
    [ $? -eq 0 ] || { echo "Articles Run Failure"; return 1; }
    echo "Articles Run Success"

}


function RemoteProcess()
{
    rm -f articles.txt
    hadoop fs -cat $_hadoop_articles_output/* | sed 's/[\(\)]//g' | sed 's/,/\t/g' > articles.txt
    unique_tag=`date "+%Y%m%d_%H%M%S_"`$RANDOM
    echo "Unique ID :"$unique_tag
    echo "Unique ID :"$unique_tag

    scp articles.txt rec@$remote_ip:$remote_folder/data/articles.txt.$unique_tag
    (ssh rec@$remote_ip "cd $remote_folder; ./run_local.sh $unique_tag > log.txt 2>&1 ; ") &
    [ $? -eq 0 ] || { echo "Remote SSH gensim doc2vec Run Failure"; return 1; }

    wait
    echo "finish the async!"

    rm -f doc2vec
    scp rec@$remote_ip:$remote_folder/output_doc2vec.txt.$unique_tag doc2vec
    scp rec@$remote_ip:$remote_folder/doc2vec_similarity.txt doc2vec_similarity.txt
    if [ ! -f ./doc2vec ]
    then 
        echo "get doc2vec failed!"
        return 1
    fi
    hadoop fs -put -f doc2vec $_hadoop_doc_topic
    ssh rec@$remote_ip "cd $remote_folder; rm -f ./output_doc2vec.txt.$unique_tag;"

    # build the related doc
    cmd="$pipeline_dir/bin/text_to_obj_sst_transformer_main \
        --input_file_path=./doc2vec_similarity.txt \
        --output_file_path=./related_docs.sst \
        --output_sst=true \
        --beishu=1000 \
    "
    echo $cmd
    $cmd

    
}


#HadoopJobStart
[ $? -eq 0 ] || { echo "Hadoopjob Run Failure"; rm -rf occupy.lock; exit $?; } 
RemoteProcess
[ $? -eq 0 ] || { echo "Remotejob Run Failure"; rm -rf occupy.lock; exit $?; }

sh ./transfer_data_related.sh

echo "Doc2vec run successed! END"
rm -rf occupy.lock
