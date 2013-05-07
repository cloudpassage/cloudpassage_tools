#!/usr/bin/env ruby
#
# William Stearns <wstearns@cloudpassage.com>

# Copyright (c) 2013, William Stearns <wstearns@cloudpassage.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of the CloudPassage, Inc. nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL CLOUDPASSAGE, INC. BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED ANDON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Based on:
# demo ruby cloudpassage API stuff
# Tim Spencer <tspencer@cloudpassage.com>
# Thanks, Tim!
#
# you may need to install the oauth2, rest-client, json, public_suffix and ip gems with:
# sudo gem install oauth2 rest-client json public_suffix ip
#Version 2.4

#======== User-modifiable values

#Maximum number of events to pull per page.  Low numbers if you have an
#unreliable link, but will cause more local disk writes.  High numbers for
#a stable link, with fewer local disk writes and a slightly faster run.
#This cannot exceed 100.
max_events_per_page = 100

#Timeouts manually extended to handle long setup time for large numbers
#of events.  Set to -1 to wait forever (although nat, proxies, and load
#balancers may cut you off externally.
timeout=600
open_timeout=600

domain_of_ip_cache=ENV['HOME']+"/dom_ip_cache.json"

api_cache_dir = ENV['HOME']+"/api_cache"

verified_ip_file = '/etc/verified-client-ips'

api_key_file = '/etc/halo-api-keys'

default_host = 'api.cloudpassage.com'

#Add the directory holding this script to the search path so we can find wlslib.rb
$:.unshift File.dirname(__FILE__)
#======== End of user-modifiable values


#======== Functions
def get_server_ips(api_host,token,ip_list,etc_hosts,timeout,open_timeout)
  #Note: ip_list and etc_hosts are modified and returned as parameters

  servers_response_json = api_get("https://#{api_host}/v1/servers",timeout,open_timeout,token)

  servers_response_json['servers'].each do |one_server|
    this_server_list = [ one_server['connecting_ip_address'] ] 
    ip_list << one_server['connecting_ip_address'] unless ip_list.include?(one_server['connecting_ip_address'])
    one_server['interfaces'].each do |one_interface|
      this_ip = one_interface['ip_address']
      ip_list << this_ip unless ip_list.include?(this_ip)
      unless this_server_list.include?(this_ip)
        case
        when this_ip.match(/^127\./)

        when this_ip.match(/^169\.254\./)

        when this_ip.match(/^0\./)

        when this_ip.match(/^22[4-9]\./)

        when this_ip.match(/^2[345][0-9]\./)

        else
          this_server_list << this_ip
        end
      end
    end

    this_server_list.each do |one_ip|
      etc_hosts << "#{one_ip}\t#{one_server['hostname']}\n"
    end
  end
end


def extract_from_events(data_events,user_locations,parent_country)
#Note, parameters parent_country and user_locations modified and returned
  data_events.each do |event|
    case event['name']
    when 'Halo login failure'
      #Make an array to hold the IP addresses for this user
      user_locations[event['actor_username']] = [ ] unless user_locations.has_key?(event['actor_username'])

      #Remember the country for later
      parent_country[event['actor_ip_address']] = event['actor_country'].to_s

      #Remember all the IP addresses for this user; we'll summarize later.
      user_locations[event['actor_username']] << event['actor_ip_address'] + "/fail/" + event['created_at']
    when 'Halo login success'
      #Make an array to hold the IP addresses for this user
      user_locations[event['actor_username']] = [ ] unless user_locations.has_key?(event['actor_username'])

      #Remember the country for later
      parent_country[event['actor_ip_address']] = event['actor_country'].to_s

      #Remember all the IP addresses for this user; we'll summarize later.
      user_locations[event['actor_username']] << event['actor_ip_address'] + "/success/" + event['created_at']
    end
  end
end

def location_summary(all_locations,parent_country,parent_domain,verified_client_ips,verified_cidr_objects,all_server_ips)
  success_count = Hash.new
  last_success = ''
  fail_count = Hash.new
  last_fail = ''
  first_event = Hash.new
  last_event = Hash.new

  all_locations.each do |one_location|
    ipaddr, state, timestamp = one_location.split('/')
    success_count[ipaddr] = 0 unless success_count.has_key?(ipaddr)
    fail_count[ipaddr] = 0 unless fail_count.has_key?(ipaddr)

    if first_event.has_key?(ipaddr)
      if timestamp < first_event[ipaddr]
        first_event[ipaddr] = timestamp
      end
    else
      first_event[ipaddr] = timestamp
    end

    if last_event.has_key?(ipaddr)
      if timestamp > last_event[ipaddr]
        last_event[ipaddr] = timestamp
      end
    else
      last_event[ipaddr] = timestamp
    end

    case state
    when 'success'
      success_count[ipaddr] += 1
      last_success = ipaddr
    when 'fail'
      fail_count[ipaddr] += 1
      last_fail = ipaddr
    end
  end

  all_ips = success_count.keys | fail_count.keys

  unverified_summary = ''
  verified_ip_summary = ''
  verified_cidr_summary = ''
  all_ips.each do |one_ip|
    halo_img = ''
    halo_img='<a href="#hosts"><img src="http://www.cloudpassage.com/images/don.gif" height="15%"></a>' if all_server_ips.include?(one_ip)

    ip_details = ''
    p_dom = get_parent_domain(one_ip,parent_domain)
    if one_ip == last_success
      ip_details << "<a href=\"http://www.dshield.org/ipinfo.html?ip=#{one_ip}\" title=\"First: #{first_event[one_ip]}, Last: #{last_event[one_ip]}\">#{one_ip}#{halo_img}</a>(<a href=\"http://www.#{p_dom}\">#{p_dom}</a>/#{parent_country[one_ip]}/<b>#{success_count[one_ip]}</b>"
    else
      ip_details << "<a href=\"http://www.dshield.org/ipinfo.html?ip=#{one_ip}\" title=\"First: #{first_event[one_ip]}, Last: #{last_event[one_ip]}\">#{one_ip}#{halo_img}</a>(<a href=\"http://www.#{p_dom}\">#{p_dom}</a>/#{parent_country[one_ip]}/#{success_count[one_ip]}"
    end
    if one_ip == last_fail
      ip_details << "/<b>#{fail_count[one_ip]}</b>"
    else
      ip_details << "/#{fail_count[one_ip]}"
    end
    ip_details << ") "

    if verified_client_ips.include?(one_ip)
      verified_ip_summary += ip_details
    else
      handled = false
      ip_object = IP::Address::Util.string_to_ip(one_ip)
      verified_cidr_objects.each do |one_cidr_object|
        if ! handled and one_cidr_object.includes? ip_object
          verified_cidr_summary += ip_details
          handled = true
        end
      end
      unverified_summary += ip_details unless handled
    end
  end

  return unverified_summary + " </td><td> " + verified_ip_summary + " </td><td> " + verified_cidr_summary
end

def write_watn_page(user_locations,parent_country,parent_domain,verified_client_ips,verified_cidr_objects,starting_date,api_client_ids,all_server_ips,etc_hosts)
  puts "<html><head><title>Where are they now?</title></head><body>"
  puts "<h2>Portal user logins</h2>"
  puts "<p>The following are the login IP addresses for all successful and failed portal logins starting on #{starting_date},"
  print "retrieved with key"
  print "s" if api_client_ids.length > 1
  print ": "
  print api_client_ids.join(', ')
  puts " .</p>"
  puts "<table border=\"1\">"
  puts "<tr><th><a href=\"https://portal.cloudpassage.com/settings/users\">Account</a></th><th>Unverified login IPs</th><th>Verified login IPs</th><th>Verified CIDR blocks</th></tr>"
  user_locations.keys.sort.each do |one_user|
    print "<tr><td>#{one_user}</td><td>"
    print location_summary(user_locations[one_user],parent_country,parent_domain,verified_client_ips,verified_cidr_objects,all_server_ips)
    #Debug
    #print "</td><td>"
    #print user_locations[one_user]
    puts "</td></tr>"
  end
  puts "</table>"
  puts "<p>After each IP are: domain of this IP, country, and the number of successful and failed logins from this IP.  If the first number is bold, the last successful login was from this IP.  If the second number is bold, the last failed login was from this IP.  Hover over the IP address to see the first and last login/login attempt timestamps.  Don the daemon indicates a current halo-managed system:</p>"
  puts "<a id=\"hosts\"><h2>Current Halo-managed hosts</h2></a>"
  puts "<pre>"
  etc_hosts.sort.uniq.each do |one_line|
    puts one_line
  end
  puts "</pre>"
  puts "<i>Report generated: #{Time.now}</i>"
  puts "</body></html>"
end

#======== End of Functions


#======== Loadable modules
require 'rubygems'
require 'optparse'
require 'oauth2'
require 'rest-client'
require 'json'
require 'resolv'
require 'public_suffix'
require 'ip'
require 'date'
load 'wlslib.rb'
#======== End of loadable modules


#======== Initialization
api_client_ids = [ ]
api_secrets = { }
api_hosts = { }
my_proxy = nil
parent_domain = Hash.new
parent_country = Hash.new
user_locations = Hash.new
verified_client_ips = [ ]
verified_cidr_objects = [ ]
starting_date = '1970-01-01'
all_server_ips = [ ]
etc_hosts = [ ]
default_key = ""
#======== End of initialization


#======== Parse command line options
optparse = OptionParser.new do |opts|
  opts.banner = "Identify IP addresses of both successful and failed portal logins for each user.  Usage: watn.rb [options]"

  opts.on("-i keyid", "--api_client_id keyid", "API Key ID (can be read only or full access).  If no key specified, use first key.  If ALL , use all keys.") do |keyid|
    api_client_ids << keyid unless api_client_ids.include?(keyid)
  end

  opts.on("-s date", "Starting date of events to process(YYYY-MM-DD format)") do |user_date|
    starting_date = user_date
  end

  opts.on_tail("-h", "--help", "Show help text") do
    $stderr.puts opts
    exit
  end
end
optparse.parse!



#======== Load api key, known good ips, and parent domain cache
default_key = load_api_keys(api_key_file,api_secrets,api_hosts,default_host)
if default_key == ""
  $stderr.puts "Unable to load any keys from #{api_key_file}, exiting."
  exit 1
end


begin
  File.open(verified_ip_file, "r") { |ip_handle|
    ip_line = ip_handle.gets
    while ip_line != nil do
      ip_line.chomp!

      #Look for cidr objects (1.2.3.4/16 or 1.2.5.6/255.255.0.0) at the beginning of the line
      if ip_line.match(/^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\/[0-9][0-9\.]*/)
        my_match = ip_line.match(/^([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\/[0-9][0-9\.]*)/)[1]
        #Convert the cidr string into an IP::CIDR object for later IP comparison tests
        verified_cidr_objects << IP::CIDR.new(my_match.to_s)
      #If no cidr, look for a raw IP address
      elsif ip_line.match(/^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/)
        verified_client_ips << ip_line.match(/^([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*)/)[1]
      end

      ip_line = ip_handle.gets
    end

    ip_handle.close
  }
rescue
  $stderr.puts "Warning: IOError caught - #{verified_ip_file} doesn't exist or unreadable?"
  $stderr.puts "This is not a fatal error, the program will continue, but it will not be able to show IP addresses or networks in the \"verified\" columns."
end


#Load up the hash that stores the cache of ip_address => parent_domain
begin
  parent_domain = JSON.parse(File.read(domain_of_ip_cache))
rescue
  $stderr.puts "Warning; unable to read #{domain_of_ip_cache}."
end





#======== Validate all user params
#FIXME - validate starting_date
if api_client_ids.length == 0
  $stderr.puts "No key requested on command line; using the first valid key in #{api_key_file}, #{default_key}."
  api_client_ids << default_key
elsif (api_client_ids.include?('ALL')) or (api_client_ids.include?('All')) or (api_client_ids.include?('all'))
  $stderr.puts "\"ALL\" requested; using all available keys in #{api_key_file}: #{api_secrets.keys.join(',')}"
  api_client_ids = api_secrets.keys.sort
end
if ! (1..100).include?(max_events_per_page)
  $stderr.puts "Invalid setting for max_events_per_page; must be between 1 and 100.  Exiting."
  exit 1
end
#Test that api_cache_dir exists (FIXME - later test that it is writeable)
unless File.directory?(api_cache_dir)
  $stderr.puts "'#{api_cache_dir}' is not a directory.  Please create it or edit api_cache_dir in this script.  Exiting."
  exit 1
end



#To accomodate a proxy, we need to handle both RestClient with the
#following one-time statement, and also as a :proxy parameter to the
#oauth2 call below.
if ENV['https_proxy'].to_s.length > 0
  my_proxy = ENV['https_proxy']
  RestClient.proxy = my_proxy
  $stderr.puts "Using proxy: #{RestClient.proxy}"
end


#Pull in event data for each api key id
api_client_ids.each do |one_client_id|

  if (api_secrets[one_client_id].to_s.length == 0)
    $stderr.puts "Invalid or missing api_client_secret for key id #{one_client_id}, skipping this key."
    $stderr.puts "The mode 600 file #{api_key_file} should contain one line per key ID/secret like:"
    $stderr.puts "myid1|mysecret1"
    $stderr.puts "myid2|mysecret2[|optional apihost:port]"
  else
    $stderr.puts "Pulling events from #{api_hosts[one_client_id]} using key #{one_client_id}, #{max_events_per_page} events per page."

    #If this script runs a long time, we'll need to get a new session key if
    #we're within a minute of the timeout.  Remember the timeout for later.
    #FIXME - get timeout from response instead of hardcoding
    revalidate_stamp = Time.now.to_i + 900
    token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
    if token == ""
      $stderr.puts "Unable to retrieve a token, skipping account #{one_client_id}."
    else
      get_server_ips(api_hosts[one_client_id],token,all_server_ips,etc_hosts,timeout,open_timeout)

      #Find the date of the first event after the user defined starting date
      first_event = cached_api_get("https://#{api_hosts[one_client_id]}/v1/events?per_page=1&page=1&since=#{starting_date}",timeout,open_timeout,token,one_client_id,api_cache_dir)
      #$stderr.puts first_event.inspect
      if first_event['count'] == 0
        $stderr.puts "Portal account #{one_client_id} does not appear to have events, skipping."
      else
        first_event_date = first_event['events'][0]['created_at'].match(/^([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9])/)
        #=> "2011-11-30T02:58:35.012790Z" => "2011-11-30"

        date_range = Date.new(first_event_date[1].to_i, first_event_date[2].to_i, first_event_date[3].to_i)..(Date.today + 1)
        date_range.each do |day|
          #puts "#{day.year} #{day.month}, #{day.day} #{(day + 1).year} #{(day + 1).month}, #{(day + 1).day}"

          more_api_params = "&since=#{day.year}-#{day.month}-#{day.day}&until=#{(day + 1).year}-#{(day + 1).month}-#{(day + 1).day}"
          $stderr.print " #{day.year}-#{day.month}-#{day.day}"
          STDERR.flush

          page = 1
          #Get the first page of events from the Halo grid.
          data = cached_api_get("https://#{api_hosts[one_client_id]}/v1/events?per_page=#{max_events_per_page}&page=#{page}#{more_api_params}",timeout,open_timeout,token,one_client_id,api_cache_dir)

          while ( data['events'].length > 0 ) do
            $stderr.print "."
            STDERR.flush

            #user_locations and parent_country modified and returned as params
            extract_from_events(data['events'],user_locations,parent_country)

            #If this script runs a long time, we'll need to get a new session key if
            #we're within a minute of the timeout
            if ( Time.now.to_i > ( revalidate_stamp - 60 ) )
              #FIXME - get timeout from response instead of hardcoding
              revalidate_stamp = Time.now.to_i + 900
              token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
            end

            #Get the next page of events from the Halo grid.
            page += 1
            data = cached_api_get("https://#{api_hosts[one_client_id]}/v1/events?per_page=#{max_events_per_page}&page=#{page}#{more_api_params}",timeout,open_timeout,token,one_client_id,api_cache_dir)
          end
        end
      end
    end
    $stderr.puts
    STDERR.flush
  end
end

write_watn_page(user_locations,parent_country,parent_domain,verified_client_ips,verified_cidr_objects,starting_date,api_client_ids,all_server_ips,etc_hosts)


begin
  File.open(domain_of_ip_cache, 'w') { |fo| fo.puts parent_domain.to_json }
rescue
  $stderr.puts "Warning; unable to save to #{domain_of_ip_cache}."
end


$stderr.puts " Complete."
exit 0
