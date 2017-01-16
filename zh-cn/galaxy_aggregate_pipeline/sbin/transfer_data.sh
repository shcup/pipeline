#!/bin/bash
cd `dirname $0`
source /etc/profile

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/batch

echo $IMAGETEXT_PIPELINE_DATA_DIR


if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst ]
then
    echo "no InvertIndex file invert_feature_rec_galaxy.sst"
    exit
fi
if [ ! -f ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_bin_galaxy.fbs ]
then
    echo "no InvertIndex file invert_feature_rec_galaxy.sst.fbs"
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

for ip in `cat ${IMAGETEXT_PIPELINE_HOME}/sbin/iplist`; do
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_galaxy.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_bin_galaxy.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_bin_galaxy.fbs
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail rec@$ip:~/data/recommendation/galaxy/detail/data/output_detail
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info.sst.fbs
done

