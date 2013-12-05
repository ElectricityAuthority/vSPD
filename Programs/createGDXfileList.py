# Python code to create a GDX filename list for use in vSPD. Specify
# a start date and end date - see st and et, yyyy,mm,dd
# Note that after about October 2013, GDX file names end in _F (or
# perhaps _I or _P) and may also have an 'x' ahead of the _F.
# Code by Dr Dave Hume.

import pandas as pd
from datetime import datetime,date

st = datetime(2013,1,1)
et = datetime(2013,10,31)

def createGDXfilelist(start,end,filename):
    file = open(filename, "w")
    file.write("/ \n")
    days = pd.date_range(start=st,end=et).map(lambda x: 'FP_' + str(x.year) + str(x.month).zfill(2) + str(x.day).zfill(2))
    days.tofile(file,sep="\r\n")
    file.write(" \n/")
    file.close()

createGDXfilelist(st,et,'vSPDfileList.inc')
