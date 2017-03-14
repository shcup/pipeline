#!/usr/bin/python
# coding=utf8


import sys
import os
reload(sys)
sys.setdefaultencoding('utf-8')

#sys.path.append("../lib/python")
#sys.path.append(os.path.dirname(os.path.realpath(__file__)) + '/../')
sys.path.append("./content_collector/")


import base64
from le_crawler.common.utils import print_object
from le_crawler.common.thrift_util import str_to_thrift
from le_crawler.proto.video.ttypes import ImageTextDoc, Album, Artist

import ctypes

so = ctypes.cdll.LoadLibrary
fasttext_lib = so("./content_collector/fasttext.so")
preprocess_function=fasttext_lib.PreProcess
preprocess_function.restype=ctypes.c_char_p
predict_function=fasttext_lib.PredictWithPreprocess
predict_function.restype=ctypes.c_char_p

#print 'LoadModel'
fasttext_lib.LoadModel("./content_collector/ft_category.bin", 0)
fasttext_lib.LoadModel("./content_collector/ft_label.bin", 1)
#print "Finish Model Loading"


def main():
  count = 1000
  while count:
    line = sys.stdin.readline()
    if not line:
      break
    line_data = line.strip().split('\t')
    vtype = line_data[0]
    data_base64 = line_data[-1]
    try:
      data_str = base64.b64decode(data_base64)
    except:
      sys.stderr.write('reporter:counter:map_error,map_decode_failed,1\n')
      continue
    if vtype == 'albums':
      video = Album()
    elif vtype == 'artists':
      video = Artist()
    else:
      video = ImageTextDoc()
    str_to_thrift(data_str, video)
    print_object(video)
    count -= 1
    continue

def post_process_category(str):
  sp = str.strip().split(';')
  res = []
  top_weight = -1.0
  for kv in sp:
    if kv:
      key_raw, split, value_str = kv.rpartition(':')
      key = key_raw[9:]
      value = float(value_str)
    if top_weight < 0:
      top_weight = value
      res.append(key)
    elif value > 0.1 and value > top_weight/3:
      res.append(key)
  return ';'.join(res)



def post_process_tag(res_str, title):
  sp = res_str.strip().split(';')
  res = []
  top_weight = -1.0
  idx = 0
  for kv in sp:
    if kv:
      key_raw, split, value_str = kv.rpartition(':')
      key = key_raw[9:]
      value = float(value_str)
    if top_weight < 0 and value > 0.001:
      top_weight = value
      res.append(key)
    elif idx < 5 and value > 0.001 and value > top_weight/10:
      res.append(key)
    elif title.find(key) != -1:
      res.append(key)
    idx = idx + 1
  return ';'.join(res)

def mapper():
  for line in sys.stdin:
    if not line:
       break
    sp = line.strip().split('\t')
    url = sp[0]
    data_base64 = sp[-1]
    try:
      data_str = base64.b64decode(data_base64)
    except:
      sys.stderr.write('reporter:counter:map_error,map_decode_failed,1\n');
      continue

    doc = ImageTextDoc()
    str_to_thrift(data_str, doc)
    
    text_input = doc.title 
    if doc and doc.main_text_list and text_input:
       text_input = text_input + "\t" + " ".join(doc.main_text_list) 
    else:
       sys.stderr.write('reporter:counter:map_error,empyt_input,1\n')
       sys.stderr.write('bad id:' + id)
       continue
    category_output = predict_function(text_input, 5 ,0)
    tag_output = predict_function(text_input, 200, 1)
    
    print doc.global_id + "\t" + post_process_category(category_output) + "\t" + post_process_tag(tag_output, doc.title)
    #print id + "\t" + text_input
    #print url + "\t" + doc.global_id + "\t"  + post_process_category(category_output) + "\t" + post_process_tag(tag_output, doc.title)

if __name__ == '__main__':
  mapper()

