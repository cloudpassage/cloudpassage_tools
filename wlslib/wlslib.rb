

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



#Version 2.6

#======== Loadable modules
require 'json'
require 'oauth2'
require 'rest-client'
require 'resolv'
require 'public_suffix'
#======== End of Loadable modules


#======== Functions
def api_live(api_host,timeout,open_timeout,token)
  zones_response_json = api_get("https://#{api_host}/v1/firewall_zones/",timeout,open_timeout,token)

  if zones_response_json['firewall_zones'].length == 0
    $stderr.puts "Unable to make API calls; firewall zone array empty"
    return false
  else
    zones_response_json['firewall_zones'].each do |one_zone|
      if (one_zone['ip_address'] == '0.0.0.0/0') and (one_zone['name'] == 'any')
        return true
      end
    end
  end

  $stderr.puts "Unable to make API calls; cannot locate zone named 'any'."
  return false
end


def get_group_names(api_host,timeout,open_timeout,token)
  group_names = { }
  groups_response_json = api_get("https://#{api_host}/v1/groups",timeout,open_timeout,token)

  groups_response_json['groups'].each do |one_group|
    group_names[one_group['id']] = one_group['name']
  end
  return group_names
end


def api_delete (url,timeout,open_timeout,token)
  json_return = ''

  rest_handle = RestClient::Resource.new url, :timeout => timeout, :open_timeout => open_timeout, :headers => { 'Authorization' => "Bearer #{token}" }
  begin
    result = rest_handle.delete
  rescue RestClient::RequestFailed => e
    $stderr.puts "While DELETE'ing #{url}"
    $stderr.puts "The request failed with HTTP status code #{e.response.code}"
    $stderr.puts "The body was:"
    $stderr.puts e.response.body
  end
  #error_string = process_return_code(result.code,result.body.to_str)
  #if error_string.length > 0
  #  $stderr.puts error_string
  #  exit 1
  #end
  if (result == nil) or (result.body == "")
    json_return = JSON '{ }'
  else
    json_return = JSON result.body
  end

  return json_return
end


def api_get (url,timeout,open_timeout,token)
  json_return = ''

  rest_handle = RestClient::Resource.new url, :timeout => timeout, :open_timeout => open_timeout, :headers => { 'Authorization' => "Bearer #{token}" }
  begin
    result = rest_handle.get
  #rescue RestClient::RequestFailed => e
  rescue => e
    $stderr.puts "While GET'ing #{url}"
    $stderr.puts "The request failed with HTTP status code #{e.response.code}"
    $stderr.puts "The body was:"
    $stderr.puts e.response.body
  end

  #error_string = process_return_code(result.code,result.body.to_str)
  #if error_string.length > 0
  #  $stderr.puts error_string
  #  exit 1
  #end

  #Debug - the following prints out the entire issues json block in pretty_printed format.
  #puts JSON.pretty_generate(JSON[result.body]);

  if (result == nil) or (result.body == "")
    json_return = JSON '{ }'
  else
    json_return = JSON result.body
  end
  return json_return
end


def api_put (url,timeout,open_timeout,token,payload)
  json_return = ''

  rest_handle = RestClient::Resource.new url, :timeout => timeout, :open_timeout => open_timeout, :headers => { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
  begin
    result = rest_handle.put(payload)
  rescue RestClient::RequestFailed => e
    $stderr.puts "While PUT'ing #{url}"
    $stderr.puts "The request failed with HTTP status code #{e.response.code}"
    $stderr.puts "The body was:"
    $stderr.puts e.response.body
  end
  #if result.code == 403
  #  #Sadly, restclient aborts on a 403 so we never get to give this.
  #  $stderr.puts "403 Forbidden returned; any chance that this is a read-only key?"
  #end
  #error_string = process_return_code(result.code,result.body.to_str)
  #if error_string.length > 0
  #  $stderr.puts error_string
  #  exit 1
  #end
  if (result == nil) or (result.body == "")
    json_return = JSON '{ }'
  else
    json_return = JSON result.body
  end
  return json_return
end


def api_post (url,timeout,open_timeout,token,payload)
  json_return = ''

  #$stderr.puts "URL: #{url}"
  #$stderr.puts "Payload: #{payload.inspect}"
  rest_handle = RestClient::Resource.new url, :timeout => timeout, :open_timeout => open_timeout, :headers => { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
  begin
    result = rest_handle.post(payload)
  rescue RestClient::RequestFailed => e
    $stderr.puts "While POST'ing #{url}"
    $stderr.puts "The request failed with HTTP status code #{e.response.code}"
    $stderr.puts "The body was:"
    $stderr.puts e.response.body
  end
  #if result.code == 403
  #  #Sadly, restclient aborts on a 403 so we never get to give this.
  #  $stderr.puts "403 Forbidden returned; any chance that this is a read-only key?"
  #end
  #error_string = process_return_code(result.code,result.body.to_str)
  #if error_string.length > 0
  #  $stderr.puts error_string
  #  exit 1
  #end
  if (result == nil) or (result.body == "")
    json_return = JSON '{ }'
  else
    json_return = JSON result.body
  end
  return json_return
end



def cached_api_get (url,timeout,open_timeout,token,api_client_id,api_cache_dir)
  json_return = ''
  dirty_filename = api_client_id + "-" + url
  clean_filename = api_cache_dir + "/" + dirty_filename.gsub(/[^a-z0-9\-]+/i, '_') + ".cache"

  #Check that url contains "/v1/events" before doing anything with cache.  Expand if other cacheable api responses found.
  if url.to_s.match('/v1/events') and File.exists?(clean_filename)
    begin
      json_return = JSON.parse(File.read(clean_filename))
    rescue
      $stderr.puts "Warning; unable to read #{clean_filename}."
    end
  end

  #If we don't have a cached answer for any reason, get one from the grid.
  if json_return.to_s.length == 0
    json_return = api_get(url,timeout,open_timeout,token)

    #If this is a /events call, Save a copy if we don't already have one on disk
    if url.to_s.match('/v1/events') and ! File.exists?(clean_filename) and json_return['pagination'] != nil
      #We only want to cache complete (therefore non-terminal) pages.
      if json_return['pagination']['next'].to_s.length > 0
        begin
          File.open(clean_filename, 'w') { |fo| fo.puts json_return.to_json }
        rescue
          $stderr.puts "Warning; unable to save to #{clean_filename}."
        end
      #else
      #  print "Not caching last page."
      end
    end

  end
  return json_return
end


def get_parent_domain(ip_address,parent_domain)
  #Lookup in cache, if not there, perform a reverse lookup for parent domain
  domain_return = ''
  if parent_domain.has_key?(ip_address)
    domain_return = parent_domain[ip_address]
  else
    #Doesn't appear to be a working parser for Arin.  Punt and use reverse dns.
    #result = Whois.query(ip_address)
    #property = result.parser
    #p property.domain

    one_host = ''
    begin
      one_host = Resolv.getname(ip_address)
    rescue
      #Ignore, reverse dns failed
    end

    if one_host.to_s.length == 0
      domain_return = 'unknown'
    else
      domain_return = cleanup_parent_domain(PublicSuffix.parse(one_host).domain)
      parent_domain[ip_address] = domain_return
      #Debug
      #$stderr.puts ip_address, one_host, domain_return
    end
  end

  return domain_return
end


def cleanup_parent_domain(dirty_domain)
  #If one has domain(s) that should be replaced with a parent organization domain (like "gstatic.com" should be "google.com") do so here.
  case dirty_domain
  when 'cloud-ips.com'          then 'rackspace.com'
  when 'myvzw.com'              then 'verizonwireless.com'
                                else dirty_domain
  end
end


def load_api_keys(api_key_file,api_secrets,api_hosts,default_host)
  #Note: api_secrets and api_hosts are modified and passed back as params
  #Remember the first ID; we'll use that if the user does not specify an ID
  first_id = ""
  begin
    File.open(api_key_file, "r") { |key_file_handle|
      key_file_line = key_file_handle.gets
      while (key_file_line != nil) do
        key_file_line.chomp!
        match_record = key_file_line.match(/^([0-9a-fA-F]{8}) *\| *([0-9a-fA-F]{32}) *\|? *([^# ]*)/)
        if match_record
          line_id = match_record[1]
          line_secret = match_record[2]
          line_host = match_record[3]
          api_secrets[line_id] = line_secret
          if line_host.to_s.length == 0
            api_hosts[line_id] = default_host
          else
            api_hosts[line_id] = line_host
          end
          first_id = line_id if first_id == ""
        end
        key_file_line = key_file_handle.gets
      end

      key_file_handle.close
    }
  rescue
    $stderr.puts "IOError caught - #{api_key_file} doesn't exist or unreadable?  Exiting."
    exit 1
  end
  return first_id
end


def get_auth_token(api_client_id,api_client_secret,my_proxy,api_host)
  #Acquire a session key from the Halo Portal for use by the rest of this script
  client = OAuth2::Client.new(api_client_id, api_client_secret,
        :connection_opts => { :proxy => my_proxy },
        :site => "https://#{api_host}",
        :token_url => '/oauth/access_token'
  )
  #FIXME - check return code
  begin
    token = client.client_credentials.get_token.token
  rescue
    $stderr.puts "Unable to retrieve a token.  Perhaps #{api_host} is inaccessible?"
    return ''
  end
  return token
end


def id_of_server(requested_name,requested_ip_address,api_host,token,timeout,open_timeout)
  if (requested_name.to_s.length == 0) and (requested_ip_address.to_s.length == 0)
      $stderr.puts "Neither requested_name nor requested_ip_address in id_of_server, exiting."
      exit 1
  end

  servers_response_json = api_get("https://#{api_host}/v1/servers",timeout,open_timeout,token)

  servers_response_json['servers'].each do |one_server|
    if (requested_name.to_s.length > 0)
      if (one_server['hostname'] == requested_name)
        return one_server['id']
      end
    elsif (requested_ip_address.to_s.length > 0)
      if (one_server['connecting_ip_address'] == requested_ip_address)
        return one_server['id']
      end

      #Also loop through interface IP addresses and match on those.
      one_server['interfaces'].each do |one_interface|
        if (one_interface['ip_address'] == requested_ip_address)
          return one_server['id']
        end
      end
    end
  end

  return nil
end


#FIXME - will need to update this to handle other types of api calls
def process_return_code(retcode,details)
  case retcode
  when 200      then ""
  when 201      then ""
  when 204      then ""
  when 401      then "Unable to retrieve events; Unauthorized/#{retcode}, exiting."
  when 403      then "Unable to retrieve events; Forbidden/#{retcode}, exiting."
  when 404      then "Unable to retrieve events; Not found/#{retcode}, exiting.  Details: #{details}"
  when 422      then "Unable to retrieve events; Validation failed/#{retcode}, exiting.  Details: #{details}"
  when 500      then "Unable to retrieve events; Internal server error/#{retcode}, exiting.  Details: #{details}"
                else "Unrecognized API return code: #{retcode}, exiting.  Details: #{details}"
  end
end


def append_to_file(one_object,out_file,warnings)
  begin
    #create, or append existing file for write
    File.open(out_file, "a") { |jsonout_handle|
      jsonout_handle.puts one_object.inspect
      jsonout_handle.close
    }
  rescue
    warnings['no_json_write'] = "Unable to write json out to #{file} ; permissions?"
  end
end
#======== End of functions
