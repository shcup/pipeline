#!/usr/bin/python
import sys
old_key=''
old_count=0
for line in sys.stdin:
	key,value=line.strip().split('\t')
	if key==old_key:
		old_count+=int(value)
	else:
		if old_key!='':
			print old_key+"\t"+str(old_count)
		old_key=key
		old_count=int(value)

if old_key!='':
	print old_key+"\t"+str(old_count)	
