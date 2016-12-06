#!/usr/bin/python
import sys
max_size=2000000
temp_dict={}
for line in sys.stdin:
	sp=line.strip().split('\t')
	for meta in sp[2:]:
		key,value=meta.strip().rsplit(":",1)
		temp_dict[key]=temp_dict.get(key,0)+1
	if len(temp_dict)>max_size:
		for key,value in temp_dict.iteritems():
			print key+"\t"+str(value)
		temp_dict={}
for key,value in temp_dict.iteritems():
	print key+"\t"+str(value)
