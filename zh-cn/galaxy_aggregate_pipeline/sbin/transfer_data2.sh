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

ENGINE_DIR=data/recommendation/galaxy/engine/dynamic_data
DETAIL_DIR=data/recommendation/galaxy/detail/data
LOCAL_INVERT_SST=${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst
TAR_INVERT_SST=$ENGINE_DIR/invert_feature_rec_galaxy.sst
LOCAL_INVERT_FBS=${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_bin_galaxy.fbs
TAR_INVERT_FBS=$ENGINE_DIR/invert_feature_rec_bin_galaxy.fbs
LOCAL_DETAIL=${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail
TAR_DETAIL=$DETAIL_DIR/output_detail
LOCAL_MEDIA_DOC_SST=${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info
TAR_MEDIA_DOC_SST=$ENGINE_DIR/media_doc_info.sst
LOCAL_MEDIA_DOC_FBS=${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs
TAR_MEDIA_DOC_FBS=$ENGINE_DIR/media_doc_info.sst.fbs


for ip in `cat ${IMAGETEXT_PIPELINE_HOME}/sbin/iplist`; do
:<<aa
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_galaxy.sst rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_galaxy.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/index_builder/invert_feature_rec_bin_galaxy.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/invert_feature_rec_bin_galaxy.fbs
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_detail rec@$ip:~/data/recommendation/galaxy/detail/data/output_detail
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info.sst
scp ${IMAGETEXT_PIPELINE_DATA_DIR}/output/detail_builder/output_media_doc_info.fbs rec@$ip:~/data/recommendation/galaxy/engine/dynamic_data/media_doc_info.sst.fbs
aa
rsync -auvzP --bwlimit=5000 $LOCAL_INVERT_SST rec@$ip:~/$TAR_INVERT_SST
rsync -auvzP --bwlimit=5000 $LOCAL_INVERT_FBS rec@$ip:~/$TAR_INVERT_FBS
rsync -auvzP --bwlimit=5000 $LOCAL_DETAIL rec@$ip:~/$TAR_DETAIL
rsync -auvzP --bwlimit=5000 $LOCAL_MEDIA_DOC_SST rec@$ip:~/$TAR_MEDIA_DOC_SST
rsync -auvzP --bwlimit=5000 $LOCAL_MEDIA_DOC_FBS rec@$ip:~/$TAR_MEDIA_DOC_FBS
done

TRANSFER_PYTHON=/letv/home/rec/common/python/transfer_data.py
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_INVERT_SST invert_feature_rec_galaxy.sst scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_INVERT_FBS invert_feature_rec_bin_galaxy.fbs scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_detail_data ~/$TAR_DETAIL output_detail scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_MEDIA_DOC_SST media_doc_info.sst scp jiaokeke1@le.com,sunhaochuan@le.com"
ssh rec@10.130.208.136 "python $TRANSFER_PYTHON galaxy_online galaxy_engine_data ~/$TAR_MEDIA_DOC_FBS media_doc_info.sst.fbs scp jiaokeke1@le.com,sunhaochuan@le.com"


