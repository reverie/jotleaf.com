
spread = 20
words = ["what", "the", "hell", "bla", "one direction", "<3", "omg"]
minDim = -1000 * spread
maxDim = 1000 * spread
numElementsTotal = 500
maxLen = 500
minLen = 500
newLineEveryN = 500
pagetitle = "dim={0}-{1}, #el={2}, len={3}-{4}, modNL={5}".format(minDim, maxDim, numElementsTotal, minLen, maxLen, newLineEveryN)

from random import randint, choice
from main.models import *

newpage = Page.objects.create(owner_id=1,title=pagetitle)

for x in xrange(numElementsTotal):
	content = " ".join([choice(words) if x % newLineEveryN else "\n" for x in xrange(1,randint(minLen, maxLen))])
	x = randint(minDim, maxDim)
	y = randint(minDim, maxDim)
	item = TextItem.objects.create(x=x,y=y,content=content,page_id=newpage.id)


"/page/{0}/".format(newpage.id)

