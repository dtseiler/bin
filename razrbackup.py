#!/usr/bin/env python

# Don Seiler, don@seiler.us 

import obexftp, ConfigParser, os
from xml.etree.ElementTree import XML
from optparse import OptionParser
from datetime import date

# This script is dependent on the Moto Razr convention of naming
# pictures in an MM-DD-YYYY_XXXX.jpg format

# Users need to create ~/.obexcopier.ini with these variables defined
# [ObexCopier]
# device = 1A:2B:3C:4D:5E:6F
# channel = 6
# source_dir = /MMC(Removable)/motorola/shared/picture
# dest_dir = /media/pictures

# Read config from ~/.obexcopier.ini
config = ConfigParser.ConfigParser()
config.read(os.path.expanduser('~/.obexcopier.ini'))

# Probably a waste of precious memory to store these again
device = config.get('ObexCopier','device')
channel = config.getint('ObexCopier','channel')
source_dir = config.get('ObexCopier','source_dir')
dest_dir = config.get('ObexCopier','dest_dir')

# Get today for default date
today = date.today().strftime("%m-%d-%y")

# Command-line handling to allow for date
parser = OptionParser()
parser.add_option("-d", "--date", dest="date", default=today, help="Grab pictures from this date, defaults to today [default: %default]",metavar="MM-DD-YY")
parser.add_option("-a", "--all", action="store_true", dest="all", default=False, help="Copy all files, regardless of date [default: %default]")
(options, args) = parser.parse_args()

# Connect to the client
print "Connecting to %s on channel %d" % (device, channel)
cli = obexftp.client(obexftp.BLUETOOTH)
cli.connect(device, channel)

# Get the list of files from the SD card picture dir
if options.all:
        print "Copying all files to disk"
else:
        print "Copying files from %s" % options.date

files_xml = cli.list(source_dir)
folder_listing = XML(files_xml)
files = folder_listing.findall('./file/')
for file in files:
        # Only handle pictures taken on the specified date
        if options.all or file.get('name').startswith(options.date):
                print "Copying %s" % file.get('name')
                data = cli.get(source_dir + '/' + file.get('name'))
                localfile = open(dest_dir + '/' + file.get('name'), 'wb')
                localfile.write(data)
                localfile.close()

# Disconnect and delete the client
cli.disconnect()
cli.delete
