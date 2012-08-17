#!/usr/bin/python
#
# demo python cloudpassage API stuff
# Tim Spencer <tspencer@cloudpassage.com>
#
apikey='FILL IN HERE' 


import json
import httplib

# connect to the portal
connection = httplib.HTTPSConnection("portal.cloudpassage.com")
header = {"x-cpauth-access": apikey}

# get a list of the active servers
connection.request("GET","/api/1/servers",'',header)
response = connection.getresponse()
jsondata =  response.read().decode()
data = json.loads(jsondata)

# print out everything in a pretty way
#print json.dumps(data, sort_keys=True, indent=4)

# iterate through the list and print out the hostnames as an example of
# how to handle json data
servers = data['servers']
for server in servers:
	print server['hostname']

connection.close()

