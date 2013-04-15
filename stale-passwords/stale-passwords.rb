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
#
#Version: 2.8

# you may need to install the oauth2, rest-client, json, date, and optparse gems.
# Sample command:
# sudo gem install {missing_gem_name}

#======== User-modifiable values
api_key_file = '/etc/halo-api-keys'
default_host = 'api.cloudpassage.com'

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

ignore_system_accounts=false
max_password_age = 0

#Timeouts manually extended to handle long setup time for large numbers
#of events.  Set to -1 to wait forever (although nat, proxies, and load
#balancers may cut you off externally.
timeout=600
open_timeout=600

all_warnings = { }
default_key = ""
#======== End of initialization



optparse = OptionParser.new do |opts|
  opts.banner = "Reports on all accounts whose passwords have not been changed recently.  Usage: stale-passwords.rb [options]"

  opts.on("-i keyid", "--api_client_id keyid", "API Key ID (can be read only or full access).  If no key specified, use first key.  If ALL , use all keys.") do |keyid|
    api_client_ids << keyid unless api_client_ids.include?(keyid)
  end

  opts.on("-m maxage", "Max password age in days") do |maxage|
    max_password_age = maxage.to_i
  end

  opts.on("--nosys", "--no_system_accounts", "Ignore all system accounts") do
    ignore_system_accounts = true
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
if max_password_age == 0
  $stderr.puts "max_password_age unset, please add a   -m maxage   parameter, exiting."
  exit
end


#To accomodate a proxy, we need to handle both RestClient with the
#following one-time statement, and also as a :proxy parameter to the
#oauth2 call below.
my_proxy = nil
if ENV['https_proxy'].to_s.length > 0
  my_proxy = ENV['https_proxy']
  RestClient.proxy = my_proxy
  $stderr.puts "Using proxy: #{RestClient.proxy}"
end


today_date = Date.today




api_client_ids.each do |one_client_id|
  if (api_secrets[one_client_id].to_s.length == 0)
    $stderr.puts "Invalid or missing api_client_secret for key id #{one_client_id}, skipping this key."
    $stderr.puts "The mode 600 file #{api_key_file} should contain one line per key ID/secret like:"
    $stderr.puts "myid1|mysecret1"
    $stderr.puts "myid2|mysecret2[|optional apihost:port]"
  else
    #Acquire a session key from the Halo Portal
    token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
    if token == ""
      $stderr.puts "Unable to retrieve a token, skipping account #{one_client_id}."
    else
      puts "#======== #{one_client_id}" if api_client_ids.length > 1

      $stderr.puts "Pulling user accounts from #{api_hosts[one_client_id]} using key #{one_client_id} .  Maximum password age: #{max_password_age}"
      $stderr.puts "Ignoring system accounts." if ignore_system_accounts

      #Get a list of server groups
      server_group_json = api_get("https://#{api_hosts[one_client_id]}/v1/groups",timeout,open_timeout,token)

      puts "Portal group,connecting IP addr,hostname,username,password_age,date of last change,shell,uid"

      server_group_json['groups'].each do |one_group|
        #We explicitly iterate through groups so you could insert a "case" block
        #here to only work with certain groups or explicitly exclude others.

        #For this server group, get a list of servers
        servers_json = api_get("https://#{api_hosts[one_client_id]}/v1/groups/#{one_group['id']}/servers",timeout,open_timeout,token)

        servers_json['servers'].each do |one_server|
          #Grab a new authorization token here as the entire run for a large number of servers could take longer than 15 minutes.
          token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
          if token == ""
            $stderr.puts "Unable to retrieve a token, will not be able to process server #{one_server['hostname']}."
          else
            #For this particular server, get a list of account names
            accounts_json = api_get("https://#{api_hosts[one_client_id]}/v1/servers/#{one_server['id']}/accounts",timeout,open_timeout,token)

            accounts_json['accounts'].each do |one_account|
              #Don't get account details at all if we're not going to display the record.
              #First, decide if we're going to display it at all.  Assume we'll display it,
              display = true
              #But filter out system accounts if requested on the command line
              if ignore_system_accounts
                case one_account['shell']
                when '/sbin/nologin', '/sbin/halt', '/sbin/shutdown', '/bin/sync', '/bin/false', '/usr/sbin/nologin'
                  display = false
                end

                case one_account['username']
                when 'abrt', 'adm', 'apache', 'avahi', 'backup', 'bin', 'chef', 'couchdb', 'daemon', 'dbus', 'distcache', 'ftp', 'games', 'gdm', 'gnats', 'gopher', 'haldaemon', 'halt', 'irc', 'libuuid', 'ldap', 'list', 'lp', 'mail', 'mailnull', 'man', 'mysql', 'named', 'news', 'nobody', 'nscd', 'ntp', 'operator', 'pcap', 'postfix', 'postgres', 'proxy', 'puppet', 'rpc', 'rpcuser', 'saslauth', 'shutdown', 'smmsp', 'squid', 'sshd', 'sync', 'sys', 'tcpdump', 'uucp', 'vcsa', 'www-data', 'xfs'
                  case one_account['uid'].to_i
                  when 1 .. 101 , 106 .. 108, 173, 499, 65534
                    display = false
                  end
                end

                case one_account['username']
                when 'munin', 'nagios', 'nfsnobody', 'nginx', 'nrpe', 'opendkim'
                  display = false
                end
              end

              if display
                #Now that we're sure we're going to display it, get the account details.
                #This saves having to make an api call for every account, even the ones
                #we're sure we'll never display
                account_details_json = api_get("https://#{api_hosts[one_client_id]}/v1/servers/#{one_server['id']}/accounts/#{one_account['username']}",timeout,open_timeout,token)

                #Format: YYYY-MM-DD
                lpc_date_string = account_details_json['account']['last_password_change']

                #Create date structures so we can find out the age of the password
                lpc_date = ""
                begin
                  if (lpc_date_string == "N/A")
                    lpc_date = Date.new(1970,1,1)
                  else
                    lpc_date = Date.new(lpc_date_string[0,4].to_i,lpc_date_string[5,2].to_i,lpc_date_string[8,2].to_i)
                  end
                rescue
                  $stderr.puts "Date conversion failure.  lpc_date_string: /#{lpc_date_string}/.  Exiting."
                  exit
                end
                password_age = (today_date - lpc_date).to_i

                #If the age of this password is > maximum specified on the command line
                if password_age >= max_password_age
                  #Output comma separated block for each account.
                  puts "#{one_group['name']},#{one_server['connecting_ip_address']},#{one_server['hostname']},#{one_account['username']},#{password_age.to_s},#{lpc_date_string},#{one_account['shell']},#{account_details_json['account']['uid']}"
                  #Future: ,#{account_details_json['account']['days_since_disabled']}
                end
              #To get a list of all system accounts ignored by --nosys, uncomment the following two lines and adjust file if wanted.
              #else
              #  append_to_file(one_account['username'],ENV['HOME']+"/system_accounts.txt",all_warnings)
              end #If we're going to display this account
            end #Loop through accounts
          end #Was able to get a replacement token
        end #Loop through servers
      end #Loop through server groups
    end #Able to get initial token
  end #Have a client secret
end #Loop through API key ID's

if $all_warnings != nil
  $stderr.puts $all_warnings.values
end

exit 0

