#!/bin/bash
class_path=".:/home/overseas_in/data/sunhaochuan/pipeline4/mr_indian_imagetext_initial_pipeline/jar/*:/usr/local/hadoop/share/hadoop/common/hadoop-common-2.6.4.jar:/usr/local/hadoop/share/hadoop/common/hadoop-common-2.6.4-tests.jar:/usr/local/hadoop/share/hadoop/common/hadoop-lzo-0.4.20-SNAPSHOT.jar:/usr/local/hadoop/share/hadoop/common/hadoop-nfs-2.6.4.jar:/usr/local/hadoop/share/hadoop/common/jdiff:/usr/local/hadoop/share/hadoop/common/lib/*:/usr/local/hadoop/share/hadoop/common/sources:/usr/local/hadoop/share/hadoop/common/templates:/usr/local/hbase/lib/*"
java -cp ${class_path} Htable.LocalHBaseGetConsole IndiaTable
