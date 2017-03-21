#!/usr/bin/python
# coding=utf8


import sys
import os
import re
reload(sys)
sys.setdefaultencoding('utf-8')

sys.path.append("./content_collector/")

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
    elif idx < 5 and value > 0.01 and value > top_weight/10:
      res.append(key)
    elif title.find(key) != -1:
      res.append(key)
    idx = idx + 1
  return ';'.join(res)


def RemoveHtmlTag(content):
  dr=re.compile(r'<[^>]+>',re.S)
  return dr.sub('', content)

def mapper():
  for line in sys.stdin:
    if not line:
       break
    sp = line.strip().split('\t')
    if len(sp) < 3:
      continue
    id = sp[0]
    title = sp[1]
    body = sp[2]

    #print id + "\t" + body 
    #print id + "\t" + RemoveHtmlTag(body)
    text_input=title + " " + RemoveHtmlTag(body)
    
    category_output = predict_function(text_input, 5 ,0)
    tag_output = predict_function(text_input, 200, 1)
    
    print id + "\t" + post_process_category(category_output) + "\t" + post_process_tag(tag_output, title)
    #print url + "\t" + doc.global_id + "\t"  + post_process_category(category_output) + "\t" + post_process_tag(tag_output, doc.title)

def dump():
  for line in sys.stdin:
    if not line:
       break
    sp = line.strip().split('\t')
    if len(sp) < 3:
      continue
    id = sp[0]
    title = sp[1]
    body = sp[2]

    text_input=title + " " + RemoveHtmlTag(body)
    
    category_output = predict_function(text_input, 5 ,0)
    tag_output = predict_function(text_input, 200, 1)
    
    #print id + "\t" + post_process_category(category_output) + "\t" + post_process_tag(tag_output, title)
    print id + "\t" + RemoveHtmlTag(body)
    print id + "\t" + body




if __name__ == '__main__':
  if len(sys.argv) == 1:
    mapper()
    exit(0)
  else:
    cmd=sys.argv[1]
    if (cmd == 'dump'):
     dump()

