#!/usr/bin/env ruby
#
# add a firewall rule to position 1 of every firewall policy we have
# Somewhat hardcoded at the moment, and it only works on Linux firewalls.
# You should be able to fix this by changing the json a bit (take out
# position, I believe?) if you need to manage windows firewalls.
#
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to say "gem install json" to make this work
#
apikey='FILL IN HERE' 
zonename = 'static bastion hosts'

require 'net/http'
require 'json/pure'

# set up connection
http = Net::HTTP.new('portal.cloudpassage.com', 443)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start

# get list of fw policy IDs
policyids = []
request = Net::HTTP::Get.new('/api/1/firewall_policies')
request.add_field("x-cpauth-access",apikey)
result = http.request(request)
data = JSON result.body
policies = data['firewall_policies']
policies.each do |policy|
	policyids << policy['id']
end

# get the fw zone we want
zoneid = ''
request = Net::HTTP::Get.new('/api/1/firewall_zones')
request.add_field("x-cpauth-access",apikey)
result = http.request(request)
data = JSON result.body
zones = data['firewall_zones']
zones.each do |zone|
	if zone['name'] == zonename
		zoneid = zone['id']
	end
end

if zoneid == ''
	puts zonename + ' does not exist.  Exiting!'
	exit 1
end

# this is the rule (note we put the zoneid we found in it):
# Syntax for the json was found in the API docs and from dumping rules out.
rule = '{
  "firewall_rule" : {
    "chain" : "INPUT",
    "active" : true,
    "firewall_interface" : null,
    "firewall_source" : {
          "id" : "' + zoneid + '",
          "type" : "FirewallZone"
    },
    "firewall_service" : null,
    "connection_states" : null,
    "action" : "ACCEPT",
    "log" : false,
    "position": 1
  }
}'

# loop through policy ids, putting the rule in
policyids.each do |fwid|
	uri = '/api/1/firewall_policies/' + fwid + '/firewall_rules'
	request = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
	request.add_field("x-cpauth-access",apikey)
	request.body = rule
	result = http.request(request)
	if result.code != 201 
		puts fwid + " said: " + result.code + ": " + result.msg
	end
end

