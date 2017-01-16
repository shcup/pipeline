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


for ip in `cat ${IMAGETEXT_PIPELINE_DATA_DIR}/iplist`; do
scp $IMAGETEXT_PIPELINE_HOME/aggregate_doc2vec/related_docs.sst rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/related_docs.sst
scp $IMAGETEXT_PIPELINE_DATA_DIR/inc_related_docs.sst rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/inc_related_docs.sst
done

