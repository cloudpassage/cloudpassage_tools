#!/usr/bin/env python2.7
#
# demo python cloudpassage API stuff
# Tim Spencer <tspencer@cloudpassage.com>
#
# This should be a lot simpler than it is, but none of the oath2
# modules seem to work well, so we do it by hand here.
#
clientid = 'XXXXXXXX'
clientsecret = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' 
host = 'api.cloudpassage.com'


import urllib
import httplib
import base64
import json

# Get the access token used for the API calls.
connection = httplib.HTTPSConnection(host)
authstring = "Basic " + base64.b64encode(clientid + ":" + clientsecret)
header = {"Authorization": authstring}
params = urllib.urlencode({'grant_type': 'client_credentials'})
connection.request("POST", '/oauth/access_token', params, header)
response = connection.getresponse()
jsondata =  response.read().decode()
data = json.loads(jsondata)
key = data['access_token']

# Do the real request using the access token in the headers
tokenheader = {"Authorization": 'Bearer ' + key}
connection.request("GET", "/v1/servers", '', tokenheader)
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

