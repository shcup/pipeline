#!/bin/bash

cd `dirname $0`
source /etc/profile

bin=../bin

if [ $# -ge 2 ]
then
  #root_dir=$1
  #input_dir=$root_dir/data/input
  #self_dir=$2
  #work_dir=$root_dir/data/$self_dir
  hadoop_dir=$2/aggregate_result/
else
  exit 1
fi
echo $hadoop_dir
#add by lujing
#hadoop_tmp_dir=$hadoop_dir/lujing/tmp
libs=/home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar
#export HADOOP_CLASSPATH=$HBASE_HOME/lib/*:classpath
#hadoop jar /home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar/HBaseUtil.jar HBaseWriteMR IndiaTable $hadoop_tmp_dir 90 /home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar/HadoopCompositeDoc.jar,/home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar/commons-codec-1.3.jar,/home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar/DPMR.jar,/home/overseas_in/indian_imagetext_pipeline_deploy/indian_imagetext_indexdetail_pipeline/jar/libthrift-0.9.3.jar
#hadoop fs -copyFromLocal stopwords.txt $hadoop_tmp_stopwords
input_data=/data/overseas_in/recommendation/index_builder/test4/aggregate_output/
#测试输出目录是否存在，若存在 则删除
hadoop fs -test -e $hadoop_dir/ReltaionsTextRankLDA/
if [ $? -eq 0 ] ;then     
    echo 'exist'  
	hadoop fs -rm -r -skipTrash $hadoop_dir/ReltaionsTextRankLDA
else  
    echo 'Directory is not exist'  
fi

hadoop fs -test -e $hadoop_dir/HotSpot/
if [ $? -eq 0 ] ;then     
    echo 'exist'  
	hadoop fs -rm -r -skipTrash $hadoop_dir/HotSpot
else  
    echo 'Directory is not exist'  
fi
 
hadoop fs -rm -r -skipTrash /user/overseas_in/.Trash/*
       
#关系强度计算
spark-submit --class related.PipeLineRelation \
--master yarn-client \
--executor-memory 4g \
--num-executors 3  \
--driver-memory 2g \
--jars $(echo $libs/HadoopCompositeDoc.jar $libs/commons-codec-1.3.jar $libs/libthrift-0.9.3.jar /usr/local/spark/lib/datanucleus-*.jar /letv/usr/local/spark-1.6.1-bin-hadoop2.6/libext/*.jar /usr/local/spark/libext|sed 's/ /,/g') \
PipelineOnSpark.jar \
$input_data \
$hadoop_dir/ReltaionsTextRankLDA/ \
100 10 90

hadoop fs -rm -r -skipTrash /user/overseas_in/.Trash/*
#热点发现
spark-submit --class findhotspot.FindHotSpot \
--master yarn-client \
--executor-memory 4g \
--num-executors 3  \
--driver-memory 2g \
--jars $(echo $libs/HadoopCompositeDoc.jar $libs/commons-codec-1.3.jar $libs/libthrift-0.9.3.jar /usr/local/spark/lib/datanucleus-*.jar /letv/usr/local/spark-1.6.1-bin-hadoop2.6/libext/*.jar /usr/local/spark/libext|sed 's/ /,/g') \
PipelineOnSpark.jar \
$input_data \
$hadoop_dir/HotSpot/ \
100 10 5

#hadoop fs -rm -r -skipTrash $hadoop_tmp_dir
#hadoop fs -rm -r -skipTrash $hadoop_tmp_stopwords
