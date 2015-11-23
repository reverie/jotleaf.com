
spread = 5
minDim = -1000 * spread
maxDim = 1000 * spread
numXElements = 20
numYElements = 20
pagetitle = "grid-page dim={0},{1}, elements={2},{3}".format(minDim, maxDim, numXElements, numYElements)

from random import randint, choice
from main.models import *

newpage = Page.objects.create(owner_id=1,title=pagetitle)

diff = maxDim - minDim
xStep = diff/numXElements
yStep = diff/numYElements

for x in xrange(minDim, maxDim, xStep):
	for y in xrange(minDim, maxDim, yStep):
		content = "{0},{1}".format(x,y)
		item = TextItem.objects.create(x=x,y=y,content=content,page_id=newpage.id)


"/page/{0}/".format(newpage.id)

