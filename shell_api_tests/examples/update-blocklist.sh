#!/bin/bash
#Copyright 2012 William Stearns <wstearns@cloudpassage.com>
#and CloudPassage Inc.

#Setup
#Make sure /usr/local/bin/ is in the path
export PATH="$PATH:/usr/local/bin"
#Load the API library that provides GetZoneDetails and UpdateZone
. /usr/local/bin/api-lib
#Tell the resty library to prepend https.....1 to all URLS
resty 'https://portal.cloudpassage.com/api/1*'


#The following three commands do:
#1) Pull down the current "Blocklist" IP zone via the API
#2) Replace the ip_address field with a new list of comma separated addresses
#pulled out of the (line separated) /admin/blocklist.txt
#3) Push the new zone up to the grid and replace the old Blocklist
#ip zone

GetZoneDetails Blocklist \
 | jsawk 'this.firewall_zone.ip_address = "'`cat /admin/blocklist.txt | tr '\n' ',' | sed -e 's/,$/\n/'`'"' \
 | UpdateZone Blocklist


