#!/bin/bash
cd `dirname $0`
source /etc/profile

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/data




if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/indian_imagetext_feature_rec_test.sst ]
then
    echo "no InvertIndex file indian_imagetext_feature_rec_test.sst"
    exit
fi
if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/indian_imagetext_feature_rec_test.sst.fbs ]
then
    echo "no InvertIndex file indian_imagetext_feature_rec_test.sst.fbs"
    exit
fi

if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail ]
then
    echo "no detail file output_detail"
    exit
fi
if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info ]
then
    echo "no ForwardIndex file output_media_doc_info"
    exit
fi
if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs ]
then
    echo "no ForwardIndex file output_media_doc_info.fbs"
    exit
fi
#if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/aggregate_related/related_docs.sst ]
#then
#    echo "no ForwardIndex file related_docs.sst"
#    exit
#fi


for ip in `cat ${IMAGETEXT_PIPELINE_DATA_DIR}/iplist`; do
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/indian_imagetext_feature_rec_test.sst rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/indian_imagetext_feature_rec_test.sst
#scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/indian_imagetext_feature_rec_test.sst.fbs rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/indian_imagetext_feature_rec_test.sst.fbs
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail rec@$ip:~/data/recommendation/topnews/detail/data/output_detail
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/media_doc_info.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/media_doc_info.sst.fbs
#scp ${IMAGETEXT_PIPELINE_DATA_DIR}/aggregate_related/related_docs.sst rec@$ip:~/data/recommendation/topnews/engine/dynamic_data/related_docs.sst
done

