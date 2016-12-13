#!/bin/bash
cd `dirname $0`
source /etc/profile

today_date=`date +%Y%m%d`
yesterday_date=`date -d $today_date' -1 day' +%Y%m%d`
the_day_before_yesterday=`date -d $today_date' -2 day' +%Y%m%d`
mkdir data

training_data1=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$today_date/data/encode/
training_data2=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$yesterday_date/data/encode/
training_data3=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$the_day_before_yesterday/data/encode/

hadoop fs -getmerge $training_data1 data/$today_date.data
hadoop fs -getmerge $training_data2 data/$yesterday_date.data
hadoop fs -getmerge $training_data3 data/$the_day_before_yesterday.data

cat data/$today_date.data data/$yesterday_date.data data/$the_day_before_yesterday.data > data/train.svm

./xgboost train.conf 
./xgboost train.conf task=dump model_in=0030.model name_dump=dump.raw.txt

#check the model
./gbdt_test dump.raw.txt key_id.dict > load_test.txt
num_line=`cat load_test.txt | grep "Success to load the GBDT model!" | wc -l`
if [ $num_line -lt 1 ]
then
	echo "the loading model failed!"
	exit
fi
#transfer the data
TRANSFER_COMMAND=/home/hadoop/rec/jiaokeke/common/transfer_data/transfer_data.py
python $TRANSFER_COMMAND all_oversea_levidi levidi_engine_data dump.raw.txt gbdt.dump.v1.txt scp
python $TRANSFER_COMMAND oversea_pre_publish publish_engine_data dump.raw.txt gbdt.dump.v1.txt scp
python $TRANSFER_COMMAND all_oversea_levidi levidi_engine_data key_id.dict feature_dict.v1.txt scp
python $TRANSFER_COMMAND oversea_pre_publish publish_engine_data key_id.dict feature_dict.v1.txt scp
