#!/usr/bin/python

### Convert from UTC to seconds and visa versa ###
# command to convert from seconds to UTC: python3 time_convert.py 712345
# command to convert from UTC to seconds: python3 time_convert.py HH MM SS


import sys
import numpy as np
import time

## Time conversion functions

def UTC2sec(utc_string):
	utc=utc_string.split(':')
	seconds=3600*int(utc[0]) + 60*int(utc[1]) + int(utc[2])
	return seconds
	
def sec2UTC(seconds):
	utc_string=time.strftime('%H:%M:%S', time.gmtime(seconds))
	return utc_string	



print ('Number of arguments:', len(sys.argv), 'arguments.')
print ('Argument List:', str(sys.argv))


if (len(sys.argv)==1):
	print('convert from seconds to UTC: python3 time_convert.py 712345 \n convert from UTC to seconds: python3 time_convert.py HH MM SS')
	
if (len(sys.argv)==2):
	print('converting from seconds to UTC')
	seconds=sys.argv[1]
	UTC=sec2UTC(int(seconds))
	print (UTC)

if (len(sys.argv)==4):
	print('converting UTC to seconds')
	HH = sys.argv[1]
	MM = sys.argv[2]
	SS = sys.argv[3]
	UTC_string = str(HH) + ':' + str(MM) + ':' + str(SS)
	seconds=UTC2sec(UTC_string)
	print(seconds)
