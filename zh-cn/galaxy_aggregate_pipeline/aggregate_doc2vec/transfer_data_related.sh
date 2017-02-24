#!/bin/bash
cd `dirname $0`
source /etc/profile

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)
IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/data



if [ ! -f $IMAGETEXT_PIPELINE_HOME/aggregate_doc2vec/related_docs.sst ]
then
    echo "no ForwardIndex file related_docs.sst"
    exit
fi

ENGINE_DIR=data/recommendation/galaxy/engine/dynamic_data
DETAIL_DIR=data/recommendation/galaxy/detail/data
LOCAL_RELATED_DOC=$IMAGETEXT_PIPELINE_HOME/aggregate_doc2vec/related_docs.sst
TAR_RELATED_DOC=$ENGINE_DIR/related_docs.sst

for ip in `cat ${IMAGETEXT_PIPELINE_HOME}/sbin/iplist`; do
#scp $IMAGETEXT_PIPELINE_HOME/aggregate_doc2vec/related_docs.sst rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/related_docs.sst
rsync -auvzP --bwlimit=50000 $LOCAL_RELATED_DOC rec@$ip:~/$TAR_RELATED_DOC
done

TRANSFER_PYTHON=/letv/home/rec/common/python/transfer_data.py

ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_RELATED_DOC related_docs.sst scp jiaokeke1@le.com,sunhaochuan@le.com"

