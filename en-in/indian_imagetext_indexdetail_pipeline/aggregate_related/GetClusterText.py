import sys

threshold=float(sys.argv[1])

for line in sys.stdin:
  items = line.strip().split('\t')
  related_docs = []
  for item in items[3:]:
    docinfo = item.split(',')
    score=float(docinfo[3])
    if (score > threshold):
      print items[0] + '\t' + docinfo[0]
      
