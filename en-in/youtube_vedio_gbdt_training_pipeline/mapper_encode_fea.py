#!/usr/bin/python
import sys
import random
import time
random.seed(time.time())


key_id_dict={}

for line in open('key_id.dict.local'):
    sp = line.strip().split('\t')
    key_id_dict[sp[0]]=sp[1]

model_key={}
for line in open('model_key'):
    model_key[line.strip()]=1

p = 0.1
for line in sys.stdin:
    reid,label,features = line.strip().split('\t', 2)
    res_string=label
    if label == '0' and random.random() > p:
        continue
    for feature in features.split('\t'):
        pre,mark,post = feature.rpartition(':')
        #if  pre in model_key:
        res_string = res_string + ' ' + key_id_dict[pre] + ':' + post
            #res_string = res_string + ' ' + pre + ':' + post

    print res_string

