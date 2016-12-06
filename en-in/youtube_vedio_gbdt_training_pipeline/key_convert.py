#!/usr/bin/python
import sys

key_id_dict={}
id_serial=0

if len(sys.argv) >= 2:
    file_path=sys.argv[1]
    print 'load exist dict: ' +  file_path
    for line in open(file_path):
        sp=line.strip().split('\t')
        id = int(sp[1])
        if (id > id_serial):
            id_serial=id
        key_id_dict[sp[0]]=id

id_serial=id_serial+1

print 'next id: ' + str(id_serial)

f_model_key=open('model_key', 'w')
f_key_id_local=open('key_id.dict.local', 'w')
f_key_id_dict=open('key_id.dict.new', 'w')

for line in sys.stdin:
    key,value = line.split('\t', 1)
    if not key in key_id_dict:
        key_id_dict[key]=id_serial
        id_serial = id_serial + 1
    f_model_key.write(key + '\n')
    f_key_id_local.write(key + '\t' + str(key_id_dict[key]) + '\n')

for k,v in key_id_dict.items():
    f_key_id_dict.write(k + '\t' + str(v) + '\n')
