#!/bin/bash
cd `dirname $0`
source /etc/profile

if [ $# -ge 4 ]
then
	if [ $# -ge 1 ]
	then
		training_date=$1
	fi
	if [ $# -ge 2 ]
	then
		pt=$2
	fi
	if [ $# -ge 3 ]
	then
		rec_area=$3
	fi
	if [ $# -ge 4 ]
	then
		pipeline=$4
	fi
else
	echo $#
	echo $@
	echo 'wrong argv'
	exit
fi


today_date=$training_date
the_day_before_yesterday=`date -d $training_date' -2 day' +%Y%m%d`
yesterday_date=`date -d $training_date' -1 day' +%Y%m%d`
tomorrow_date=`date -d $training_date' +1 day' +%Y%m%d`

dump_feature_path3=/data/rec/log/server_log/online_feature_dump_by_day/$the_day_before_yesterday/*/*/
dump_feature_path2=/data/rec/log/server_log/online_feature_dump_by_day/$yesterday_date/*/*/
dump_feature_path1=/data/rec/log/server_log/online_feature_dump_by_day/$training_date/*/*/

session_log_path=/data/rec/indian_log_analyze/expose_click_new/recp_session_log/1_${today_date}_${tomorrow_date}
output_path=/data/rec/ctr_predict/$pipeline/$pt/$rec_area/$training_date/data
encode_fea_path=/data/rec/ctr_predict/$pipeline/$pt/$rec_area/$training_date/data/encode/


hadoop fs -rm -r -skipTrash $output_path/feature_train


hadoop_binary=hadoop                                                                                             
hdfs_bin_dir=/data/rec/ctr_predict/bin/

cmd="./dump_feature_session_log_join \
     --auto_run \
     --num_mapper=100 \
     --num_reducer=300 \
     --input_format=text \
     --output_format=text \
     --hdfs_output_dir=$output_path/feature_train \
     --hdfs_input_paths=$dump_feature_path1,$dump_feature_path2,$dump_feature_path3,$session_log_path/* \
     --enable_multi_mapper_output=false \
     --hdfs_bin_dir=$hdfs_bin_dir \
     --hadoop_binary=$hadoop_binary \
     --lib_jars=/home/hadoop/rec/sunhaochuan/jar/custom_format_1_1_2.jar \
     --compatible_mod=false \
     --compress_map_output=false \
     --compress_mapper_out_value=false \
     --fileoutput_compress=false \
     --shuffle_input_buffer_percent=0.5 \
     --dump_feature_input_path=feature_dump \
     --lejian_session_log_input_path=expose_click \
     --dense_feature_builder=YoutubeNormalizedScoreAndTimestampDenseFeatureBuilder \
     --aggregated_by_user=true \
     --split_minsize=1294967295 \
     "
#--dense_feature_builder=YoutubeDenseFeatureBuilder \
echo $cmd
$cmd
[ $? -eq 0 ] || { echo "MrDumpFeatureSessionLogJoin Run Failure"; exit 1; }

hadoop fs -rm -r -skipTrash $output_path/count_fea
hadoop jar /usr/local/hadoop/share/hadoop/tools/lib/hadoop-streaming-2.6.0.jar -D mapred.output.compress=0 -D mapred.reduce.tasks=120 -input $output_path/feature_train -output $output_path/count_fea -mapper ./mapper_count_fea.py  -reducer ./reducer_count_fea.py -file mapper_count_fea.py -file reducer_count_fea.py
[ $? -eq 0 ] || { echo "MrDumpFeatureCount Run Failure"; exit 1; }

hadoop fs -rm -r -skipTrash $output_path/fea_cover
hadoop jar /usr/local/hadoop/share/hadoop/tools/lib/hadoop-streaming-2.6.0.jar -D mapred.output.compress=0 -D mapred.reduce.tasks=120 -input $output_path/feature_train -output $output_path/fea_cover -mapper ./mapper_fea_cover.py  -reducer ./reducer_fea_cover.py -file mapper_fea_cover.py -file reducer_fea_cover.py
[ $? -eq 0 ] || { echo "MrDumpFeatureFeaCover Run Failure"; exit 1; }

if [ ! -f key_id.dict ]
then
    touch key_id.dict
fi
hadoop fs -cat $output_path/count_fea/part* | python ./key_convert.py key_id.dict
mv key_id.dict.new key_id.dict

#转换key_id.dict的格式，为plot feature_importance准备
#hadoop fs -cat $output_path/count_fea/part* | python ./kc_plot_fea.py 
#mv id_key.dict.new id_key.dict


hadoop fs -put -f key_id.dict /data/rec/ctr_predict/$pipeline/$pt/$rec_area/key_id.dict

key_num=`wc -l model_key | awk '{print $1}'`
if [ $key_num -lt 10 ]
then
	echo 'too few modle key in training data (less than 10)'
	#exit
fi
hadoop fs -rm -r -skipTrash $encode_fea_path
hadoop jar /usr/local/hadoop/share/hadoop/tools/lib/hadoop-streaming-2.6.0.jar -D mapred.output.compress=0  -Dmapreduce.input.fileinputformat.split.minsize=1024 -D mapreduce.tasktracker.map.tasks.maximum=30 -D mapred.reduce.tasks=0 -Dmapreduce.map.memory.mb=3000 -input $output_path/feature_train -output $encode_fea_path -mapper ./mapper_encode_fea.py -file ./mapper_encode_fea.py -file ./model_key -file ./key_id.dict.local 
