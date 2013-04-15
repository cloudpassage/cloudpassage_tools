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
# you may need to install the oauth2, rest-client, and json gems with:
# sudo gem install oauth2 rest-client json

#Version 0.6

#======== User-modifiable values
api_key_file = '/etc/halo-api-keys'
default_host = 'api.cloudpassage.com'

#Timeouts manually extended to handle long setup time for large numbers
#of events.  Set to -1 to wait forever (although nat, proxies, and load
#balancers may cut you off externally.
timeout=600
open_timeout=600

#Add the directory holding this script to the search path so we can find wlslib.rb
$:.unshift File.dirname(__FILE__)
#======== End of user-modifiable values


#======== Functions

#======== End of functions


#======== Loadable modules
require 'rubygems'
require 'optparse'
require 'oauth2'
require 'rest-client'
require 'json'
load 'wlslib.rb'
#======== End of loadable modules


#======== Initialization
api_client_ids = [ ]
api_secrets = { }
api_hosts = { }
my_proxy = nil
zone_to_modify = ""
add_addresses = [ ]
remove_addresses = [ ]
address_list = [ ]
erase_list = false
stdin_type = ""
default_key = ""
#======== End of initialization



optparse = OptionParser.new do |opts|
  opts.banner = "Add or remove an address from a CloudPassage Halo IP zone.  Usage: modify-ip-zone.rb [options]"

  opts.on("-i keyid", "--api_client_id keyid", "API Key ID (can be read only or full access).  If no key specified, use first key.  If ALL , use all keys.") do |keyid|
    api_client_ids << keyid unless api_client_ids.include?(keyid)
  end

  opts.on("-z zone_name", "Name of the zone you wish to modify (surround name by quotes if needed)") do |zone_name|
    zone_to_modify = zone_name
  end

  opts.on("-a new_ip", "IP address to add to the list") do |new_addr|
    add_addresses << new_addr unless add_addresses.include?(new_addr)
  end

  opts.on("--add-stdin", "read IP addresses to add to the list from stdin") do
    if stdin_type == "remove"
      $stderr.puts "Cannot specify both --add-stdin and --remove-stdin, exiting."
      exit 1
    end
    stdin_type = "add"
  end

  opts.on("-r new_ip", "IP address to remove from the list") do |new_addr|
    remove_addresses << new_addr unless remove_addresses.include?(new_addr)
  end

  opts.on("--remove-stdin", "read IP addresses to remove from the list from stdin") do
    if stdin_type == "add"
      $stderr.puts "Cannot specify both --add-stdin and --remove-stdin, exiting."
      exit 1
    end
    stdin_type = "remove"
  end

  opts.on("--empty", "Start with an empty list (ignores the current zone contents)") do
    erase_list = true
  end

  opts.on_tail("-h", "--help", "Show help text") do
    $stderr.puts opts
    exit
  end
end
optparse.parse!

default_key = load_api_keys(api_key_file,api_secrets,api_hosts,default_host)
if default_key == ""
  $stderr.puts "Unable to load any keys from #{api_key_file}, exiting."
  exit 1
end


#Load addresses from stdin if requested
if stdin_type == "add"
  STDIN.read.split("\n").each do |one_addr|
    add_addresses << one_addr unless add_addresses.include?(one_addr)
  end
elsif stdin_type == "remove"
  STDIN.read.split("\n").each do |one_addr|
    remove_addresses << one_addr unless remove_addresses.include?(one_addr)
  end
end

#Validate all user params
if (api_client_ids.length == 0)
  $stderr.puts "No key requested on command line; using the first valid key in #{api_key_file}, #{default_key}."
  api_client_ids << default_key
elsif (api_client_ids.include?('ALL')) or (api_client_ids.include?('All')) or (api_client_ids.include?('all'))
  $stderr.puts "\"ALL\" requested; using all available keys in #{api_key_file}: #{api_secrets.keys.join(',')}"
  api_client_ids = api_secrets.keys.sort
end


#To accomodate a proxy, we need to handle both RestClient with the
#following one-time statement, and also as a :proxy parameter to the
#oauth2 call below.
if ENV['https_proxy'].to_s.length > 0
  my_proxy = ENV['https_proxy']
  RestClient.proxy = my_proxy
  $stderr.puts "Using proxy: #{RestClient.proxy}"
end

api_client_ids.each do |one_client_id|
  if (api_secrets[one_client_id].to_s.length == 0)
    $stderr.puts "Invalid or missing api_client_secret for key id #{one_client_id}, skipping this key."
    $stderr.puts "The mode 600 file #{api_key_file} should contain one line per key ID/secret like:"
    $stderr.puts "myid1|mysecret1"
    $stderr.puts "myid2|mysecret2[|optional apihost:port]"
  else
    $stderr.puts "Modifying zone #{zone_to_modify} via #{api_hosts[one_client_id]} using key #{one_client_id}"

    #Use a simple file lock to make sure that for a given API key only one
    #copy of the script is running at a time.  If you're working with 5 API
    #keys that means you could have up to 5 copies running at once, one for
    #each key.
    #FIXME loop on failure 10 times
    lock_file = "/tmp/modify-ip-zone-#{one_client_id}.lock"
    File.open(lock_file, "a") {}
    unless File.new(lock_file).flock( File::LOCK_NB | File::LOCK_EX )
      $stderr.puts "It appears another copy of this script is running and holds the lock on #{lock_file}.  Exiting."
      exit
    end

    #Acquire a session key from the Halo Portal for use by the rest of this script
    token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
    if token == ""
      $stderr.puts "Unable to retrieve a token, skipping account #{one_client_id}."
    else
      #Pull down the current zone from the Halo grid.
      zone_json = api_get("https://#{api_hosts[one_client_id]}/v1/firewall_zones",timeout,open_timeout,token)

      zone_id = ""
      zone_list_string = ""
      zone_array = [ ]
      zone_json['firewall_zones'].each do |one_zone|
        if zone_to_modify == one_zone['name']
          zone_id = one_zone['id']
          zone_list_string = one_zone['ip_address']
        end
      end

      if zone_id == ""
        $stderr.puts "Unable to locate zone #{zone_to_modify} in this portal, skipping modification."
      else
        #$stderr.puts zone_id
        $stderr.puts "Original zone: #{zone_list_string}"

        if erase_list
          $stderr.puts "Clearing all addresses from old zone."
          zone_list_string = ""
        end

        address_list = zone_list_string.tr(' ','').split(",")

        address_list += add_addresses

        address_list -= remove_addresses

        if address_list.length == 0
          $stderr.puts "No addresses left in a single IP zone, Halo zones cannot be empty, exiting."
          exit 1
        end

        if address_list.length > 375
          $stderr.puts "Too many addresses (#{address_list.length} > 375) for a single IP zone, exiting."
          exit 1
        end

        zone_list_string = address_list.join(',')
        $stderr.puts "New zone: #{zone_list_string}"

        replacement_zone_json = "{ \"firewall_zone\" : { \"ip_address\" : \"#{zone_list_string}\" } }"

        result = api_put("https://#{api_hosts[one_client_id]}/v1/firewall_zones/#{zone_id}",timeout,open_timeout,token,replacement_zone_json)

      end
    end
  end
end
$stderr.puts "Complete."


exit


