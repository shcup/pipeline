#!/bin/sh


cd /home/overseas_in/data/sunhaochuan/pipeline4/mr_indian_imagetext_initial_pipeline/sbin 

exe_date=`date +%Y%m%d`
echo $exe_date
echo `date +%Y%m%d:%H%S`
./mr_indian_imagetext_initial_pipeline_inc.sh $exe_date inc inc_test4 > inc_scene.txt 2>&1
res=$?
echo $res
if [ $res -eq 0 ]  
then
    echo "start to pipeline2"
    cd /home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/sbin
    ./mr_indian_imagetext_indexdetail_pipeline_for_hourly_inc_data.sh test4 inc_test4 > hourly_inc_builder_scene.txt 2>&1
    ./mr_indian_imagetext_indexdetail_pipeline.sh test4  > scene.txt 2>&1
fi



