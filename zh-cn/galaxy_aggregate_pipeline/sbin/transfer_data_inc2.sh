#!/bin/bash
cd `dirname $0`
source /etc/profile

IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)

IMAGETEXT_PIPELINE_DATA_DIR=${IMAGETEXT_PIPELINE_HOME}/latest

ENGINE_DIR=data/recommendation/galaxy/engine/dynamic_data
DETAIL_DIR=data/recommendation/galaxy/detail/data
LOCAL_INVERT_SST=${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst
TAR_INVERT_SST=$ENGINE_DIR/invert_feature_rec_galaxy.sst
LOCAL_DETAIL_SST=${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail
TAR_DETAIL_SST=$DETAIL_DIR/output_detail_hourly_inc
LOCAL_MEDIA_DOC_INC=${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs
TAR_MEDIA_DOC_INC=$ENGINE_DIR/media_doc_info_hourly_inc.sst.fbs


for ip in `cat ${IMAGETEXT_PIPELINE_HOME}/sbin/iplist`; do
:<<black
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_galaxy.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail rec@$ip:~/data/recommendation/galaxy/detail/data/output_detail_hourly_inc
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info_hourly_inc.sst.fbs
black
rsync -auvzP --bwlimit=50000 $LOCAL_INVERT_SST rec@$ip:~/$TAR_INVERT_SST
rsync -auvzP --bwlimit=50000 $LOCAL_DETAIL_SST rec@$ip:~/$TAR_DETAIL_SST
rsync -auvzP --bwlimit=50000 $LOCAL_MEDIA_DOC_INC rec@$ip:~/$TAR_MEDIA_DOC_INC
done

TRANSFER_PYTHON=/letv/home/rec/common/python/transfer_data.py
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_INVERT_SST invert_feature_rec_galaxy.sst scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_detail_data ~/$TAR_DETAIL_SST output_detail_hourly_inc scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_MEDIA_DOC_INC media_doc_info_hourly_inc.sst.fbs scp jiaokeke1@le.com,sunhaochuan@le.com"




