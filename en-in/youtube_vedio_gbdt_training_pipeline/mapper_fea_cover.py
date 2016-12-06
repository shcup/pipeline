#!/usr/bin/python
import sys

class Stat:
  feature_count_1 = 0
  feature_count_0 = 0
  set_feature_count_1 = 0
  set_feature_count_0 = 0

stat_map={}

for line in sys.stdin:
  sp = line.strip().split('\t')

  for meta in sp[2:]:
    key,value=meta.strip().rsplit(":",1)
    if key not in stat_map:
      stat_map[key] = Stat()
    tmp_stat = stat_map[key]

    if sp[1] == '1':
      tmp_stat.feature_count_1 += 1
      if float(value) > 0:
        tmp_stat.set_feature_count_1 += 1
    else:
      tmp_stat.feature_count_0 += 1
      if float(value) > 0:
        tmp_stat.set_feature_count_0 += 1

  if len(stat_map) > 20000:
    for key,value in stat_map.iteritems():
      print "%s\t%d\t%d\t%d\t%d" % (
            key, value.feature_count_1, value.feature_count_0, \
            value.set_feature_count_1, value.set_feature_count_0)
    stat_map = {}
  print "total\t1\t1\t1\t1"

for key,value in stat_map.iteritems():
  print "%s\t%d\t%d\t%d\t%d" % (
        key, value.feature_count_1, value.feature_count_0, \
        value.set_feature_count_1, value.set_feature_count_0)
