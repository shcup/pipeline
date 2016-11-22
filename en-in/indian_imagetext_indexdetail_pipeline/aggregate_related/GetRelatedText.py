import sys

for line in sys.stdin:
  items = line.strip().split('\t')
  related_docs=[]
  for item in items[3:]:
    docinfo = item.split(',')
    if (float(docinfo[3]) < 0.7):
      related_docs.append([docinfo[0], float(docinfo[3])])
    else:
      related_docs.append([docinfo[0], 0-float(docinfo[3])])
  related_docs.sort(lambda x,y:cmp(x[1],y[1]), reverse=True)
  res = items[0]
  for docs in  related_docs:
    res = res + '\t' +  docs[0] + ',' + str(docs[1])
  print res
