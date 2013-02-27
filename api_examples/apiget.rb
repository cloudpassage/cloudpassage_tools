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

#To accomodate a proxy, we need to handle both RestClient with the
#following one-time statement, and also as a :proxy parameter to the
#oauth2 call below.
my_proxy = nil
if ENV['https_proxy'].to_s.length > 0
  my_proxy = ENV['https_proxy']
  RestClient.proxy = my_proxy
  $stderr.puts "Using proxy: #{RestClient.proxy}"
end

client = OAuth2::Client.new(clientid, clientsecret,
        :connection_opts => { :proxy => my_proxy },
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

