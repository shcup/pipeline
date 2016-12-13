#!/bin/bash
cd `dirname $0`
source /etc/profile

today_date=`date +%Y%m%d`
yesterday_date=`date -d $today_date' -1 day' +%Y%m%d`
the_day_before_yesterday=`date -d $today_date' -2 day' +%Y%m%d`

rm -rf measure
mkdir measure
training_data1=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$today_date/data/encode/
training_data2=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$yesterday_date/data/encode/
training_data3=/data/rec/ctr_predict/youtube_gbdt_pipeline/0003/rec_1902/$the_day_before_yesterday/data/encode/

hadoop fs -getmerge $training_data1 measure/$today_date.data
hadoop fs -getmerge $training_data2 measure/$yesterday_date.data
hadoop fs -getmerge $training_data3 measure/$the_day_before_yesterday.data

cat measure/$yesterday_date.data measure/$the_day_before_yesterday.data > measure/train.svm
mv measure/$today_date.data measure/test.svm

./xgboost measure.conf 


