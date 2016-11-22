#!/bin/bash
IMAGETEXT_PIPELINE_HOME=$(cd $(dirname $0); cd ..; echo $PWD)
cd `dirname $0`
source /etc/profile


if [ $# -eq 3 ]
then
  input_dir=$1
  work_dir=$2
  hadoop_dir=$3
else
  exit 1
fi


mkdir $work_dir
local_forward_index=$input_dir/forward_index.dat
local_invert_index=$input_dir/invert_index.data
local_output=$work_dir/output
mkdir $local_output

HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH=/data/overseas_in/recommendation/pipeline/prepare_cluster_output
hadoop fs -rm -r ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/InvertIndex_data
hadoop fs -mkdir -p ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/InvertIndex_data
hadoop fs -put $input_dir/invert_index.data ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/InvertIndex_data
hadoop fs -rm -r ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/ForwardIndex_data
hadoop fs -mkdir -p ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/ForwardIndex_data
hadoop fs -put $input_dir/forward_index.dat ${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/ForwardIndex_data
HADOOP_IMAGETEXT_CLUSTER_CHAIN_WAND_RESULT_OUTPUT_PATH=/data/overseas_in/recommendation/pipeline/cluster_chain_wand
#hadoop fs -rm -r -skipTrash ${HADOOP_IMAGETEXT_CLUSTER_CHAIN_WAND_RESULT_OUTPUT_PATH}

hadoop_binary=hadoop
hdfs_bin_dir=/data/overseas_in/recommendation/pipeline/tmp/bin

cmd="${IMAGETEXT_PIPELINE_HOME}/bin/cluster_chain_mapreduce
     --auto_run
     --num_mapper=100
     --num_reducer=0
     --input_format=text
     --output_format=text
     --hdfs_output_dir=${HADOOP_IMAGETEXT_CLUSTER_CHAIN_WAND_RESULT_OUTPUT_PATH}
     --hdfs_input_paths=${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/ForwardIndex_data
     --enable_multi_mapper_output=false
     --hdfs_bin_dir=$hdfs_bin_dir
     --hadoop_binary=$hadoop_binary
     --lib_jars=${IMAGETEXT_PIPELINE_HOME}/lib/java/custom_format_1_1_2.jar
     --uploading_files=${local_invert_index}
     --compatible_mod=false
     --compress_map_output=false
     --compress_mapper_out_value=false
     --fileoutput_compress=false
     --shuffle_input_buffer_percent=0.5
     "
nohup $cmd

hadoop fs -text ${HADOOP_IMAGETEXT_CLUSTER_CHAIN_WAND_RESULT_OUTPUT_PATH}/part* > ${local_output}/cluster_chain_wand_data_


cat ${local_output}/cluster_chain_wand_data_ | awk -F '\t' -v OFS="\t" '{print $1,$2,$4}' > ${local_output}/cluster_chain_wand_data_ini
cat ${local_output}/cluster_chain_wand_data_ | awk -F '\t' -v OFS="\t" '{print $1,$4}' > ${local_output}/doc_norm_dict

HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_1_OUTPUT_PATH=/data/overseas_in/recommendation/pipeline/inner_product_map_1
HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_2_OUTPUT_PATH=/data/overseas_in/recommendation/pipeline/inner_product_map_2
HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_3_OUTPUT_PATH=/data/overseas_in/recommendation/pipeline/inner_product_map_all
HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_4_OUTPUT_PATH=/data/overseas_in/recommendation/pipeline/inner_product_reduce

cat ${local_output}/cluster_chain_wand_data_ini | awk -F '\t' -v OFS="\t" '{if(NR<=230000){print}}' > ${local_output}/cluster_chain_wand_data_1
cat ${local_output}/cluster_chain_wand_data_ini | awk -F '\t' -v OFS="\t" '{if(NR>230000){print}}' > ${local_output}/cluster_chain_wand_data_2
cp ${local_output}/cluster_chain_wand_data_1 ${local_output}/cluster_chain_wand_data

hadoop fs -rm -r -skipTrash ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_1_OUTPUT_PATH}

cmd="${IMAGETEXT_PIPELINE_HOME}/bin/calc_sim_for_cluster
    --auto_run
    --num_mapper=300
    --num_reducer=0
    --input_format=text
    --output_format=text
    --hdfs_output_dir=${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_1_OUTPUT_PATH}
    --hdfs_input_paths=${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/InvertIndex_data
    --enable_multi_mapper_output=false
    --hdfs_bin_dir=$hdfs_bin_dir
    --hadoop_binary=$hadoop_binary
    --lib_jars=${IMAGETEXT_PIPELINE_HOME}/lib/java/custom_format_1_1_2.jar
    --uploading_files=$local_output/cluster_chain_wand_data
    --compatible_mod=false
    --compress_map_output=false
    --compress_mapper_out_value=false
    --fileoutput_compress=false
    --shuffle_input_buffer_percent=0.5
    "
nohup $cmd

hadoop fs -text ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_1_OUTPUT_PATH}/part* > ${local_output}/inner_product_map_1

cp ${local_output}/cluster_chain_wand_data_2 ${local_output}/cluster_chain_wand_data

hadoop fs -rm -r -skipTrash ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_2_OUTPUT_PATH}

cmd="${IMAGETEXT_PIPELINE_HOME}/bin/calc_sim_for_cluster
    --auto_run
    --num_mapper=300
    --num_reducer=0
    --input_format=text
    --output_format=text
    --hdfs_output_dir=${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_2_OUTPUT_PATH}
    --hdfs_input_paths=${HADOOP_IMAGETEXT_CLUSTER_PREPARED_DATA_PATH}/InvertIndex_data
    --enable_multi_mapper_output=false
    --hdfs_bin_dir=$hdfs_bin_dir
    --hadoop_binary=$hadoop_binary
    --lib_jars=${IMAGETEXT_PIPELINE_HOME}/lib/java/custom_format_1_1_2.jar
    --uploading_files=$local_output/cluster_chain_wand_data
    --compatible_mod=false
    --compress_map_output=false
    --compress_mapper_out_value=false
    --fileoutput_compress=false
    --shuffle_input_buffer_percent=0.5
    "
nohup $cmd

hadoop fs -text ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_2_OUTPUT_PATH}/part* > ${local_output}/inner_product_map_2

hadoop fs -rm -r -skipTrash ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_3_OUTPUT_PATH}

hadoop fs -mkdir -p ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_3_OUTPUT_PATH}

cat ${local_output}/inner_product_map_1 > ${local_output}/inner_product_map_all
cat ${local_output}/inner_product_map_2 >> ${local_output}/inner_product_map_all

hadoop fs -put ${local_output}/inner_product_map_all ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_3_OUTPUT_PATH}
 
hadoop fs -rm -r -skipTrash ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_4_OUTPUT_PATH}

cmd="${IMAGETEXT_PIPELINE_HOME}/bin/calc_sim_for_cluster_only_reducer
    --auto_run
    --num_mapper=30
    --num_reducer=200
    --input_format=text
    --output_format=text
    --hdfs_output_dir=${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_4_OUTPUT_PATH}
    --hdfs_input_paths=${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_3_OUTPUT_PATH}
    --enable_multi_mapper_output=false
    --hdfs_bin_dir=$hdfs_bin_dir
    --hadoop_binary=$hadoop_binary
    --lib_jars=${IMAGETEXT_PIPELINE_HOME}/lib/java/custom_format_1_1_2.jar
    --uploading_files=${local_output}/doc_norm_dict
    --compatible_mod=false
    --compress_map_output=false
    --compress_mapper_out_value=false
    --fileoutput_compress=false
    --shuffle_input_buffer_percent=0.5
    "
nohup $cmd

hadoop fs -text ${HADOOP_IMAGETEXT_CLUSTER_INNERPRODUCT_4_OUTPUT_PATH}/part* > ${local_output}/cos_sim_dict

cmd="${IMAGETEXT_PIPELINE_HOME}/bin/generate_cluster_main ${local_output}/cos_sim_dict ${local_output}/cluster_result 0.8"

nohup $cmd

hadoop fs -put -f ${local_output}/cluster_result $hadoop_dir/docid_clusterid_clustersize




