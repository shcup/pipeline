#!/usr/bin/python
import sys
old_key=''
total_c1 = 0
total_c2 = 0
total_c3 = 0
total_c4 = 0
for line in sys.stdin:
    key,c1,c2,c3,c4 = line.strip().split('\t')
    if key==old_key:
        total_c1 += int(c1)
        total_c2 += int(c2)
        total_c3 += int(c3)
        total_c4 += int(c4)
    else:
        if old_key!='':
            print "%s\t%d\t%d\t%d\t%d" % (
                  old_key, total_c1, total_c2, total_c3, total_c4)
        old_key=key
        total_c1 = int(c1)
        total_c2 = int(c2)
        total_c3 = int(c3)
        total_c4 = int(c4)
if old_key!='':
   print "%s\t%d\t%d\t%d\t%d" % (
         key, total_c1, total_c2, total_c3, total_c4)
