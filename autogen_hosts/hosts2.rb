#!/usr/bin/env ruby
#
# demo ruby cloudpassage API stuff to emit /etc/hosts
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to say "gem install json" to make this work
#
clientid = 'XXXXXXXX'
clientsecret = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' 
host = 'api.cloudpassage.com'

require 'json'
require 'rest-client'

response = RestClient.post "https://#{host}/oauth/access_token", {
	grant_type: 'client_credentials',
	client_id: clientid,
	client_secret: clientsecret
}
token = JSON.parse(response)["access_token"]

result = RestClient.get "https://#{host}/api/1/servers", {
	'Authorization' => "Bearer #{token}",
        'Content-type' => "application/json"
}

puts '# hosts file from our CP api'
puts '# WARNING! This whole file is generated from /etc/hosts.template'
puts '# and the output of hosts.rb.'
puts '# Any changes will be overwritten shortly'

data = JSON result.body
servers = data['servers']
servers.each do |server|
	puts server['connecting_ip_address'] + "	" + server['hostname']
end

