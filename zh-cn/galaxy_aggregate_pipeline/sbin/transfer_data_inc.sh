#!/bin/bash
cd `dirname $0`
source /etc/profile

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/latest



if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs ]
then
    echo "no InvertIndex file indian_imagetext_feature_rec_test.sst.fbs"
    exit
fi

if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail ]
then
    echo "no detail file output_detail"
    exit
fi
if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs ]
then
    echo "no ForwardIndex file output_media_doc_info.fbs"
    exit
fi


for ip in `cat ${IMAGETEXT_PIPELINE_HOME}/sbin/iplist`; do
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/indian_imagetext_feature_rec_test.sst rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_galaxy.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail rec@$ip:~/data/recommendation/galaxy/detail/data/output_detail_hourly_inc
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info_hourly_inc.sst.fbs
done

