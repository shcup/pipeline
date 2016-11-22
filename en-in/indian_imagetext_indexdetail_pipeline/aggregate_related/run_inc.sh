#!/bin/bash

cd `dirname $0`
source /etc/profile

remote_ip=10.121.145.29
remote_folder=/home/rec/data/pipeline/ml/gensim_doc2vec


if [ -f occupy_inc.lock ]
then
    echo "Related is already run! END"
    exit 1
else
    touch occupy_inc.lock
fi

if [ $# -ge 2 ]
then
  pipeline_dir=$1
  hadoop_dir=$2
else
  rm -f occupy_inc.lock
  exit 1
fi

awk -F '\t' '{print $1}' related_docs.txt > black_list.tt
$pipeline_dir/bin/document_cluster_int_main invert_index black_list.txt composite_doc.txt > inc_related_docs.txt
