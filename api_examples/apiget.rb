#!/usr/bin/env ruby
#
# demo ruby cloudpassage API stuff
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to install the oauth2 and rest-client gems
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

result = RestClient.get "https://#{host}/v1/servers", {
        'Authorization' => "Bearer #{token}"
}

data = JSON result.body
servers = data['servers']
servers.each do |server|
	puts server['connecting_ip_address'] + " " + server['hostname']
	#puts server['hostname']
end

