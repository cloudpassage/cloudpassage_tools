#!/usr/bin/env ruby
#
# demo python cloudpassage API stuff
# Tim Spencer <tspencer@cloudpassage.com>
#
# you may need to say "gem install json" to make this work
#
apikey='FILL IN HERE' 

require 'net/http'
require 'json/pure'

request = Net::HTTP::Get.new('/api/1/users')
request.add_field("x-cpauth-access",apikey)
http = Net::HTTP.new('portal.cloudpassage.com', 443)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start
result = http.request(request)

data = JSON result.body
users = data['users']
users.each do |user|
	puts user['username']
end

