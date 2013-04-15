#!/usr/bin/env ruby
#
# William Stearns <wstearns@cloudpassage.com>
# Copyright (c) 2013, CloudPassage, Inc.
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
require 'date'
load 'wlslib.rb'
#======== End of loadable modules


#======== Initialization
api_client_ids = [ ]
api_secrets = { }
api_hosts = { }
my_proxy = nil
report_dir = "./"
default_key = ""
#======== End of initialization



optparse = OptionParser.new do |opts|
  opts.banner = "Download CloudPassage policies.  Usage: get-policies.rb [options]"

  opts.on("-i keyid", "--api_client_id keyid", "API Key ID (can be read only or full access).  If no key specified, use first key.  If ALL , use all keys.") do |keyid|
    api_client_ids << keyid unless api_client_ids.include?(keyid)
  end

  opts.on("--report_dir report_dir", "Report directory, to which the exported json policy files will be written.  Must exist.  Any reports in this directory will be overwritten.  Defaults to current directory.") do |input_dir|
    report_dir = input_dir.to_s + "/"
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



#Validate all user params
if (api_client_ids.length == 0)
  $stderr.puts "No key requested on command line; using the first valid key in #{api_key_file}, #{default_key}."
  api_client_ids << default_key
elsif (api_client_ids.include?('ALL')) or (api_client_ids.include?('All')) or (api_client_ids.include?('all'))
  $stderr.puts "\"ALL\" requested; using all available keys in #{api_key_file}: #{api_secrets.keys.join(',')}"
  api_client_ids = api_secrets.keys.sort
end

unless File.directory?(report_dir)
  $stderr.puts "'#{report_dir}' is not a directory.  Please create it or specify a different directory with parameter --report_dir.  Exiting."
  exit 1
end
$stderr.puts "Saving reports to #{report_dir}"


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
    $stderr.puts "Pulling events from #{api_hosts[one_client_id]} using key #{one_client_id}"

    #Use a simple file lock to make sure that for a given API key only one
    #copy of the script is running at a time.  If you're working with 5 API
    #keys that means you could have up to 5 copies running at once, one for
    #each key.
    lock_file = "/tmp/archive-policies-#{one_client_id}.lock"
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
      #Get the list of FIM policies from the Halo grid.
      fim_policies_json = api_get("https://#{api_hosts[one_client_id]}/v1/fim_policies",timeout,open_timeout,token)

      fim_policies_json['fim_policies'].each do |one_policy_summary|
        $stderr.puts "Downloading FIM policy: #{one_policy_summary['name']}"
        one_policy_json = api_get("https://#{api_hosts[one_client_id]}/v1/fim_policies/#{one_policy_summary['id']}",timeout,open_timeout,token)
        clean_filename = report_dir + "/fim-#{one_client_id}-" + one_policy_summary['name'].gsub(/[^a-z0-9\-]+/i, '_') + ".#{Date.today.year}#{Date.today.month}#{Date.today.day}.json"
        begin
          File.open(clean_filename, 'w') { |fo| fo.puts one_policy_json.to_json }
        rescue
          $stderr.puts "Warning; unable to save to #{clean_filename}."
        end
      end

      #Get the list of firewall policies from the Halo grid.
      firewall_policies_json = api_get("https://#{api_hosts[one_client_id]}/v1/firewall_policies",timeout,open_timeout,token)

      firewall_policies_json['firewall_policies'].each do |one_policy_summary|
        $stderr.puts "Downloading firewall policy: #{one_policy_summary['name']}"
        one_policy_json = api_get("https://#{api_hosts[one_client_id]}/v1/firewall_policies/#{one_policy_summary['id']}",timeout,open_timeout,token)
        clean_filename = report_dir + "/firewall-#{one_client_id}-" + one_policy_summary['name'].gsub(/[^a-z0-9\-]+/i, '_') + ".#{Date.today.year}#{Date.today.month}#{Date.today.day}.json"
        begin
          File.open(clean_filename, 'w') { |fo| fo.puts one_policy_json.to_json }
        rescue
          $stderr.puts "Warning; unable to save to #{clean_filename}."
        end
      end

      #Get the list of configuration policies from the Halo grid.
      #configuration_policies_json = api_get("https://#{api_hosts[one_client_id]}/v1/policies",timeout,open_timeout,token)

      ##FIXME - check that "policies" is the hash key used for the policy array when this API call shows up
      #configuration_policies_json['policies'].each do |one_policy_summary|
      #  $stderr.puts "Downloading configuration policy: #{one_policy_summary['name']}"
      #  one_policy_json = api_get("https://#{api_hosts[one_client_id]}/v1/policies/#{one_policy_summary['id']}",timeout,open_timeout,token)
      #  clean_filename = report_dir + "/configuration-#{one_client_id}-" + one_policy_summary['name'].gsub(/[^a-z0-9\-]+/i, '_') + ".#{Date.today.year}#{Date.today.month}#{Date.today.day}.json"
      #  begin
      #    File.open(clean_filename, 'w') { |fo| fo.puts one_policy_json.to_json }
      #  rescue
      #    $stderr.puts "Warning; unable to save to #{clean_filename}."
      #  end
      #end

    end
  end
end

$stderr.puts "As of the time this program was written, the API does not provide a way to download configuration policies.  These will have to be downloaded manually from the portal."
puts " Complete."



