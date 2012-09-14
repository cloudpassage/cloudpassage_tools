#!/usr/bin/env ruby
#
# demo ruby cloudpassage API stuff to emit /etc/hosts
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to say "gem install json" to make this work
#
apikey='XXXAPIKEYXXX' 

require 'net/http'
require 'json/pure'

request = Net::HTTP::Get.new('/api/1/servers')
request.add_field("x-cpauth-access",apikey)
http = Net::HTTP.new('portal.cloudpassage.com', 443)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start
result = http.request(request)

puts '# hosts file from our CP api'
puts '# WARNING! This whole file is generated from /etc/hosts.template'
puts '# and the output of hosts.rb.'
puts '# Any changes will be overwritten shortly'

data = JSON result.body
servers = data['servers']
servers.each do |server|
	puts server['connecting_ip_address'] + "	" + server['hostname']
end

