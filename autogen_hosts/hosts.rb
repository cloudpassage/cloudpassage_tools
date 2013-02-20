#!/usr/bin/env ruby
#
# demo ruby cloudpassage API stuff to emit /etc/hosts
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to say "gem install json" to make this work
#
clientid = 'XXXXXXXX'
clientsecret = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' 
host = 'api.cloudpassage.com'

require 'oauth2'
require 'rest-client'
require 'json'

client = OAuth2::Client.new(clientid, clientsecret,
	:site => "https://#{host}",
	:token_url => '/oauth/access_token'
)

token = client.client_credentials.get_token.token

result = RestClient.get "https://#{host}/api/1/servers", {
        'Authorization' => "Bearer #{token}"
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

