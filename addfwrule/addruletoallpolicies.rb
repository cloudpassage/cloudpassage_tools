#!/usr/bin/env ruby
#
# add a firewall rule to position 1 of every firewall policy we have
# Somewhat hardcoded at the moment, and it only works on Linux firewalls.
# You should be able to fix this by changing the json a bit (take out
# position, I believe?) if you need to manage windows firewalls.
#
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to install a few gems to make this work:
#	oauth2, rest-client, json

# API ID and key created via Halo portal:
# https://portal.cloudpassage.com/settings/users (API tab)
# Read id and key from environment for convenience
clientid = ENV['HALO_ID']
clientsecret = ENV['HALO_SECRET_KEY']

host = 'api.cloudpassage.com'
zonename = 'static bastion hosts'


require 'oauth2'
require 'rest-client'

# get the auth token
client = OAuth2::Client.new(clientid, clientsecret,
        :site => "https://#{host}",
        :access_url => '/oauth/access_token',
        :token_url => '/oauth/access_token'
)

token = client.client_credentials.get_token.token

# get list of fw policy IDs
result = RestClient.get "https://#{host}/api/1/firewall_policies", {
        'Authorization' => "Bearer #{token}"
}
policyids = []
data = JSON result.body
policies = data['firewall_policies']
policies.each do |policy|
	policyids << policy['id']
end

# get the fw zone we want
zoneid = ''
result = RestClient.get "https://#{host}/api/1/firewall_zones", {
        'Authorization' => "Bearer #{token}"
}
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
	result = RestClient.post "https://#{host}/api/1/firewall_policies/#{fwid}/firewall_rules", rule, {
		'Authorization' => "Bearer #{token}",
		'Content-Type' =>'application/json'
	}
	if result.code != 201 
		puts fwid + " said: " + result.code + ": " + result.msg
	end
end

