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

#Version 3.5

#======== User-modifiable values
api_key_file = '/etc/halo-api-keys'
default_host = 'api.cloudpassage.com'

#Timeouts manually extended to handle long setup time for large numbers
#of events.  Set to -1 to wait forever (although nat, proxies, and load
#balancers may cut you off externally.
timeout=600
open_timeout=600

$debug = false

#Add the directory holding this script to the search path so we can find wlslib.rb
$:.unshift File.dirname(__FILE__)
#======== End of user-modifiable values


#======== Functions
#The following load_* functions extract information from api results and store
#that in aspects and aspect_scores hashes, which are passed back modified as 
#parameters.

#Pull out information from /servers/{oneid}/accounts.  This is the server OS
#(windows, unless we find a root account) and the existence of non-system 
#accounts.
def load_accounts(aspects,aspect_scores,accounts_json,server_id,server_os)
  $stderr.puts "loading accounts" if $debug
  #Assume OS is windows unless we find a valid root account
  server_os[server_id] = "windows"
  accounts_json['accounts'].each do |one_account|
    server_os[server_id] = "linux" if (one_account['username'] == "root") and (one_account['uid'].to_s == "0")

    case one_account['shell']
    when '/sbin/nologin','/sbin/shutdown','/bin/sync','/sbin/halt','/bin/false'
    else
      if one_account['uid'].to_i >= 100
        case one_account['username']
        when 'libuuid','nobody','sshd'
        else
          aspect_name = "Acct-#{one_account['username']}"
          aspects[aspect_name] = { } unless aspects.has_key?(aspect_name)
          aspects[aspect_name][server_id] = "exists"
          aspect_scores[aspect_name] = { } unless aspect_scores.has_key?(aspect_name)
          aspect_scores[aspect_name][server_id] = 0
        end
      end
    end
  end
  #if server_os[server_id] == "windows"
  #  puts JSON.pretty_generate(accounts_json)
  #  #As of 20130324, windows returns        { "accounts": { } }
  #  exit
  #end
end


#Extract the parent domain of the connecting_ip_address from an
#individual server json block from /groups/{groupid}/servers .
def load_servers(aspects,aspect_scores,one_server,server_id,parent_domain_cache)
  if $debug
    $stderr.puts "loading servers"
    $stderr.puts one_server['connecting_ip_address'], get_parent_domain(one_server['connecting_ip_address'],parent_domain_cache)
  end
  aspect_name = "IP-Connecting IP parent domain"
  aspects[aspect_name] = { } unless aspects.has_key?(aspect_name)
  aspects[aspect_name][server_id] = get_parent_domain(one_server['connecting_ip_address'],parent_domain_cache)
  aspect_scores[aspect_name] = { } unless aspect_scores.has_key?(aspect_name)
  aspect_scores[aspect_name][server_id] = 0
end


#Extract server state, svm package names, svm cve vulnerabilities, sca
#rules, and sca checks from /servers/{oneid}/issues
def load_issues(aspects,aspect_scores,issues_json,server_id,status_scores)
  $stderr.puts "loading issues" if $debug
  #Load "state", which will always be active, to get a server list
  aspects['State'] = { } unless aspects.has_key?('State')
  aspects['State'][server_id] = issues_json['state']
  aspect_scores['State'] = { } unless aspect_scores.has_key?('State')
  case issues_json['state']
  when "active"
    #State is always active at the moment.
    aspect_scores['State'][server_id] = 0
  else
    aspect_scores['State'][server_id] = 2
  end

  #Load up package names and versions
  if issues_json['svm'] != nil
    issues_json['svm']['findings'].each do |one_package|
      package_name = "Pkg-#{one_package['package_name']}"
      score = 0
      if one_package['critical']
        score = 3
      else
        score = 2
      end
      aspects[package_name] = { } unless aspects.has_key?(package_name)
      aspects[package_name][server_id] = one_package['package_version']
      aspect_scores[package_name] = { } unless aspect_scores.has_key?(package_name)
      aspect_scores[package_name][server_id] = score

      one_package['cve_entries'].each do |one_cve|
        cve_name = package_name + "(#{one_cve['cve_entry']})"
        aspects[cve_name] = { } unless aspects.has_key?(cve_name)
        if one_cve['suppressed']
          aspects[cve_name][server_id] = 'suppressed'
        else
          aspects[cve_name][server_id] = 'vulnerable'
        end
        aspect_scores[cve_name] = { } unless aspect_scores.has_key?(cve_name)
        aspect_scores[cve_name][server_id] = score
      end
    end
  end

  #Load up each of the scan rules and checks
  if (issues_json['sca'] == nil) or (issues_json['sca']['findings'] == nil)
    if (issues_json['sca'] != nil) and issues_json['sca']['status'] != "failed"
      $stderr.puts "Nil sca or findings for:"
      $stderr.puts issues_json.inspect
    end
  else
    issues_json['sca']['findings'].each do |one_rule|
      #Remove any html in the rule name
      rule_name = "Cfg rule-#{one_rule['rule_name'].to_s.gsub(/<[^>]*>/,"")}"

      #Load up the rules first
      aspects[rule_name] = { } unless aspects.has_key?(rule_name)
      aspects[rule_name][server_id] = one_rule['status']
      aspect_scores[rule_name] = { } unless aspect_scores.has_key?(rule_name)
      aspect_scores[rule_name][server_id] = status_scores["#{one_rule['status']}/#{one_rule['critical']}"]

      #And now load up their component checks
      one_rule['details'].each do |one_check|
        if one_check['status'] == 'indeterminate'
          check_value = 'indeterminate'
        else
          check_value = one_check['actual'].to_s.gsub(/<[^>]*>/,"")
        end
        check_name = ""
        case one_check['type']
        when 'configuration'
          check_name = rule_name + " (check-#{one_check['target']} has #{one_check['config_key']} #{one_check['config_key_value_delimiter']} #{one_check['expected']})"
        when 'dir_acl', 'file_acl'
          check_name = rule_name + " (check-#{one_check['target']} ACL is #{one_check['expected']})"
        when 'dir_owner_gid', 'file_owner_gid'
          check_name = rule_name + " (check-#{one_check['target']} owned by group #{one_check['expected']})"
        when 'dir_owner_uid', 'file_owner_uid'
          check_name = rule_name + " (check-#{one_check['target']} owned by #{one_check['expected']})"
        when 'dir_sticky_bit',
          check_name = rule_name + " (world writeable directory without sticky bit: #{one_check['expected']})"
        when 'file_presence'
          check_name = rule_name + " (check-#{one_check['target']} exists: #{one_check['expected']})"
        when 'file_regex'	#Does not list the regex
#{"actual"=>false, "target"=>"/etc/pam.d/system-auth-ac",
#"status"=>"bad", "expected"=>true, "scan_status"=>"ok",
#"type"=>"file_regex"}
          check_name = rule_name + " (check-#{one_check['target']} has a regex: #{one_check['expected']})"
        when 'file_set_gid'
          check_name = rule_name + " (check-#{one_check['target']} setgid: #{one_check['expected']})"
        when 'file_set_uid'
          check_name = rule_name + " (check-#{one_check['target']} setuid: #{one_check['expected']})"
        when 'group_gid_is'
          check_name = rule_name + " (check-#{one_check['target']} has gid #{one_check['expected']})"
        when 'group_has_password'
          check_name = rule_name + " (check-#{one_check['target']} has password: #{one_check['expected']})"
        when 'group_has_users'
          check_name = rule_name + " (check-#{one_check['target']} has users: #{one_check['expected']})"
        when 'password_is_username'
          check_name = rule_name + " (check-#{one_check['target']} has password = username: #{one_check['expected']})"
        when 'port_white'	#Network service accessibility, does not list interface name as a field
#{"scan_status"=>"ok", "bound_process"=>"sshd", "target"=>"*",
#"actual"=>"22/TCP", "status"=>"bad", "type"=>"port_white",
#"port_scan_status"=>"open", "expected"=>"99/TCP"}
          check_name = rule_name + " (check-only open ports: #{one_check['expected']})"
        when 'port_process'	#Network service processes, does not list interface or port
#{"expected"=>"bash", "scan_status"=>"ok", "type"=>"port_process",
#"actual"=>"sshd", "target"=>"*", "status"=>"bad"}
          check_name = rule_name + " (check-Port N should only have listener #{one_check['expected']})"
        when 'process_effective_gid'
          check_name = rule_name + " (check-#{one_check['target']} running as group #{one_check['expected']})"
        when 'process_effective_uid'
          check_name = rule_name + " (check-#{one_check['target']} running as #{one_check['expected']})"
        when 'process_presence'
          check_name = rule_name + " (check-#{one_check['target']} should be running: #{one_check['expected']})"
        when 'user_file_presence'
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} contains #{one_check['patterns']}: #{one_check['expected']})"
        when 'user_has_groups'
          check_name = rule_name + " (check-#{one_check['target']} is a member of only #{one_check['expected']})"
        when 'user_has_logged_in'
          check_name = rule_name + " (check-#{one_check['target']} has logged in: #{one_check['expected']})"
        when 'user_has_not_logged_in'
          check_name = rule_name + " (check-#{one_check['target']} has not logged in: #{one_check['expected']})"
        when 'user_has_password'
          check_name = rule_name + " (check-#{one_check['target']} has a password: #{one_check['expected']})"
        when 'user_home_presence'
          check_name = rule_name + " (check-#{one_check['target']} has a home directory #{one_check['home_directory']}: #{one_check['expected']})"
        when 'user_home_file_group_ownership'		#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} has files group owned by another user: #{one_check['expected']})"
        when 'user_home_file_ownership'			#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} has files owned by another user: #{one_check['expected']})"
        when 'user_home_files_umask'			#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} sets insecure umask: #{one_check['expected']})"
        when 'user_home_files_detect_path_statements'	#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} has no unsafe PATH statements in #{one_check['home_directory']}: #{one_check['expected']})"
        when 'user_home_group_ownership'
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} owned by gid: #{one_check['expected']})"
        when 'user_home_ownership'
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} owned by uid: #{one_check['expected']})"
        when 'user_home_device_files'			#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} has character or block devices: #{one_check['expected']})"
        when 'user_home_setgid_files'			#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} has setgid files: #{one_check['expected']})"
        when 'user_home_setuid_files'			#This has an array with the file names we could later harvest
          check_name = rule_name + " (check-#{one_check['target']} home directory #{one_check['home_directory']} has setuid files: #{one_check['expected']})"
        when 'user_uid_is'
          check_name = rule_name + " (check-#{one_check['target']} has uid #{one_check['expected']})"
        when 'windows_file_presence'
#{"expected"=>true, "target"=>"C:\\note1-junk.txt", "actual"=>false, "status"=>"bad", "type"=>"windows_file_presence", "scan_status"=>"not_found"}
          check_name = rule_name + " (check-#{one_check['target']} = #{one_check['expected']})"
        when 'windows_local_security_policy'
#{"scan_status"=>"ok", "status"=>"bad", "type"=>"windows_local_security_policy", "target"=>"secedit", "actual"=>"0", "expected"=>"1"}
          check_name = rule_name + " (check-win_local_sec_pol, #{one_check['target']} exists: #{one_check['expected']})"
        else
          $stderr.puts "No check_name defined for #{one_check['type']}."
          $stderr.puts one_check.inspect
        end

        check_name = check_name.to_s.gsub(/<[^>]*>/,"")

        case one_check['type']
        when 'configuration', 'dir_acl', 'dir_owner_gid', 'dir_owner_uid', 'dir_sticky_bit', 'file_acl', 'file_owner_gid', 'file_owner_uid', 'file_presence', 'file_regex', 'file_set_gid', 'file_set_uid', 'group_gid_is', 'group_has_password', 'group_has_users', 'password_is_username', 'port_process', 'port_white', 'process_effective_gid', 'process_effective_uid', 'process_presence', 'user_file_presence', 'user_has_groups', 'user_has_logged_in', 'user_has_not_logged_in', 'user_has_password', 'user_home_file_group_ownership', 'user_home_file_ownership', 'user_home_group_ownership', 'user_home_ownership', 'user_home_presence', 'user_home_device_files', 'user_home_files_detect_path_statements', 'user_home_files_umask', 'user_home_setgid_files', 'user_home_setuid_files', 'user_uid_is', 'windows_file_presence', 'windows_local_security_policy'
          aspects[check_name] = { } unless aspects.has_key?(check_name)
          aspects[check_name][server_id] = check_value
          aspect_scores[check_name] = { } unless aspect_scores.has_key?(check_name)
          aspect_scores[check_name][server_id] = status_scores["#{one_check['status']}/#{one_rule['critical']}"]
        else
          $stderr.puts "No check storage requested for #{one_check['type']}."
          $stderr.puts one_check.inspect
        end
      end
    end
  end
end


#This is called to print a report for a group, all servers in a portal
#account, or all servers in all portal accounts requested.
def print_oott_report(group_name,aspects,aspect_scores,all_server_ids,server_hostnames,report_dir,server_count,table_names,server_os)
  $stderr.puts "printing report" if $debug
  report_file=report_dir + '/oott-' + group_name.gsub(/[^a-z0-9\-]+/i, '_') + '.html'
  table_line_arrays = { }

  begin
    #Create, or truncate existing file for write
    File.open(report_file, "w") { |report_handle|
      #Print an HTML header
      report_handle.puts "<html><head><title>One of these things...</title></head><body>"
      report_handle.puts '<script type="text/javascript"> function toggle(obj) { var obj=document.getElementById(obj); if (obj.style.display == "block") obj.style.display = "none"; else obj.style.display = "block"; } </script>'
      report_handle.print "<h2>#{group_name}: #{server_count} server"
      report_handle.print "s" if server_count != 1
      report_handle.puts "</h2>"

      if all_server_ids.length == 0
        report_handle.puts "<p>No servers in this group.</p>"
      else
        hostnames = { }
        hostnames['linux'] = [ ]
        hostnames['windows'] = [ ]
        all_server_ids.each do |one_id|
          hostnames[server_os[one_id]] << server_hostnames[one_id]
        end

        report_handle.print "<p><img src=\"https://portal.cloudpassage.com/assets/linux_20px.png\"> #{hostnames['linux'].length} Linux server"
        report_handle.print "s" if hostnames['linux'].length != 1
        report_handle.puts ": "
        report_handle.puts hostnames['linux'].sort.join(" ")
        report_handle.puts "</p>"

        report_handle.print "<p><img src=\"https://portal.cloudpassage.com/assets/windows_20px.png\"> #{hostnames['windows'].length} Windows server"
        report_handle.print "s" if hostnames['windows'].length != 1
        report_handle.puts ": "
        report_handle.puts hostnames['windows'].sort.join(" ")
        report_handle.puts "</p>"

        report_handle.puts "<p>Each table row contains an expected value in column 1.  All other columns hold an observed value with a number of servers on which it was seen.  Click on the number to see the server names, click again to hide.  Observed values are colored according to severity: good, <font color=\"gray\">indeterminate</font>, <font color=\"orange\">bad</font>, and <font color=\"red\">bad and critical</font>.</p>"
      end

      #Load up each of the summary lines, organized into multiple tables (one for each of the 8 scores, 0-7)
      aspects.keys.sort.each do |one_aspect|
        line_score, table_cell_array = summarize_one_aspect(aspects[one_aspect],aspect_scores[one_aspect],one_aspect,server_hostnames,server_count)
        table_line_arrays[line_score] = [ ] unless table_line_arrays.has_key?(line_score)
        table_line_arrays[line_score] << table_cell_array
      end

      #Print out each table, starting with the highest severity and working down to the lowest
      7.downto(0) do |line_score|
        if table_line_arrays.has_key?(line_score)
          report_handle.puts "<h3>#{table_names[line_score]}</h3>"
          report_handle.puts "<table border=\"1\">"
          report_handle.puts "<tr><th>Server aspect:expected value</th><th colspan=3>Observed:server count</th></tr>"

          #While we have any line arrays left to process
          while table_line_arrays[line_score].length > 0
            identical_value_block = [ ]
            remaining_lines = [ ]
            #Grab (and remove) the first available line array
            identical_value_block << table_line_arrays[line_score].shift

            #Now look for any other line arrays with identical columns 2+ out of the remaining line arrays
            table_line_arrays[line_score].each do |one_array|
              if line_arrays_equal(identical_value_block[0],one_array)
                #Transfer any identical lines from table_line_arrays to indentical_value_block
                identical_value_block << one_array
              else
                remaining_lines << one_array
              end
            end
            #Push the remaining (non-equal) lines back onto
            #table_line_arrays so we can look for the next block.
            table_line_arrays[line_score] = remaining_lines

            #Print the first cell of the first row
            report_handle.print "<tr><td>#{identical_value_block[0][0]}</td>"
            #For the remining cells in the first row, print them but use rowspan=number_of_rows so they'll span down over the remaining rows
            identical_value_block[0].drop(1).each do |one_cell|
              report_handle.print "<td rowspan=#{identical_value_block.length}>#{one_cell}</td>"
            end
            report_handle.puts "</tr>"
            #For the rest of the lines, just print column one as the remaining columns are spanned.
            identical_value_block.drop(1).each do |one_line_array|
              report_handle.puts "<tr><td>" + one_line_array[0] + "</td></tr>\n"
            end
          end

          report_handle.puts "</table>"
        end
      end

      #Finally an HTML footer
      report_handle.puts "</body></html>"
      report_handle.close
    }
  rescue
    $stderr.puts "Unable to write report to #{report_file} ; permissions?"
  end
end


#Compare 2 line arrays.  We're looking for 2 lines with identical _observed
#values_, so we ignore the first column ([0]) and only compare the others.
#We also strip out all html.  This function supports our ability to group
#aspects together with rowspan.
def line_arrays_equal(line_array1, line_array2)
  arrays_equal = true

  #They have to be the same length for there to be any chance of being equal
  if line_array1.length != line_array2.length
    arrays_equal = false
  else
    #Check each cell except the first.  Strip out any html and compare each
    (1..line_array1.length-1).each do |one_index|
      arrays_equal = false if line_array1[one_index].to_s.gsub(/<[^>]*>/,"") != line_array2[one_index].to_s.gsub(/<[^>]*>/,"")
    end
  end
  return arrays_equal
end


#This turns our original one_aspect[hostid] => value hash into a
#value_owners[value] => [ hostids] hash.
def summarize_one_aspect(one_aspect,one_aspect_scores,aspect_name,server_hostnames,server_count)
  line_score = 0
  value_owners = { }

  #Each table cell string is an element of the array.  We hand it up to make comparisons easier in parent routine
  #Since the first column holds the server aspect, we initialize the array with that in [0]
  table_cell_array = [ aspect_name ]

  #The one_aspect hash holds { host_id => value } pairs.  We pull these out and store them in 
  #value_owners, which holds { value => [ list of host_ids ] } pairs.
  one_aspect.each_key do |one_host_id|
    one_value = one_aspect[one_host_id]

    #Pull out the highest score for any cell to give a score to the entire line
    if one_aspect_scores.has_key?(one_host_id)
      line_score = one_aspect_scores[one_host_id] if one_aspect_scores[one_host_id] > line_score
      case one_aspect_scores[one_host_id]
      #when 0	#Good
        #one_value = "<font color=\"black\">" + one_value + "</font>"
      when 1	#Indeterminate
        one_value = "<font color=\"gray\">" + one_value + "</font>"
      when 2	#Bad
        one_value = "<font color=\"orange\">" + one_value + "</font>"
      when 3	#Bad+critical
        one_value = "<font color=\"red\">" + one_value + "</font>"
      end
    else
      $stderr.puts "Warning, no score assigned to #{aspect_name} on host #{one_host_id}"
    end

    value_owners[one_value] = [ ] unless value_owners.has_key?(one_value)
    value_owners[one_value] << one_host_id unless value_owners[one_value].include?(one_host_id)

  end

  #The usual score range is 0 (good) to 3 (bad + critical).  We raise that by 4 (4-7) if 
  #there's any disagreement, which is the case if any value cell has <server_count servers.
  disagree_nudge = 0
  value_owners.each_key do |one_value|
    disagree_nudge = 4 if (value_owners[one_value].length != server_count)
  end
  line_score += disagree_nudge

  #For each value we found, build a table cell with the number of servers with that value and 
  #"all", or a list of those server names if < all servers.
  value_owners.each_key do |one_value|
    cell_content = "#{one_value}:"
    if disagree_nudge == 0
      case value_owners[one_value].length
      when 1
        cell_content += "sole"
      when 2
        cell_content += "both"
      else
        cell_content += "all #{value_owners[one_value].length}"
      end
    else
      #We only print the hostnames if there's disagreement

      #Keep the div ID's unique
      $html_div_count += 1
      #Following hides the server list until you click on the count
      cell_content += "<a href=\"javascript: void(0);\" onClick=\"toggle('d#{$html_div_count}')\">#{value_owners[one_value].length}</a>"
      cell_content += "<div id=\"d#{$html_div_count}\" style=\"display:none;\">"

      cell_content += " ("
      value_owners[one_value].each do |one_owner|
        cell_content += " #{server_hostnames[one_owner]}"
      end
      cell_content += " )</div>"

    end
    table_cell_array << cell_content
  end
  return line_score, table_cell_array
end

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
report_dir = './'
server_hostnames = { }		#{ hostid => hostname }
server_os = { }			#{ hostid => "linux", "hostid" => "windows" }
global_aspects = { }		#{ aspect_name => { hostid => value } }
global_aspect_scores = { }	#{ aspect_name => { hostid => severity_score(0..3) } }
global_server_ids = [ ]		#A list of all server IDS for the final global report
$all_warnings = { }
$html_div_count = 0
parent_domain_cache = { }
status_scores = {
  "bad/true" => 3,
  "bad/false" => 2,
  "indeterminate/true" => 1,
  "indeterminate/false" => 1,
  "good/true" => 0,
  "good/false" => 0
}
table_names = {
  7 => "Servers disagree, severity bad and critical",
  6 => "Servers disagree, severity bad",
  5 => "Servers disagree, indeterminate",
  4 => "Servers disagree, severity good",
  3 => "Servers agree, severity bad and critical",
  2 => "Servers agree, severity bad",
  1 => "Servers agree, indeterminate",
  0 => "Servers agree, severity good"
}
default_key = ""
#======== End of initialization



optparse = OptionParser.new do |opts|
  opts.banner = "One of these things is not like the others; provide group summaries of the differences between systems in the group.  Usage: oott.rb [options]"

  opts.on("-i keyid", "--api_client_id keyid", "API Key ID (can be read only or full access).  If no key specified, use first key.  If ALL , use all keys.") do |keyid|
    api_client_ids << keyid unless api_client_ids.include?(keyid)
  end

  opts.on("--report_dir report_dir", "Report directory, to which the html reports will be written.  Must exist.  Any reports in this directory will be overwritten.  Defaults to current directory.") do |input_dir|
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


#Use a simple file lock to make sure that only one
#copy of the script is running at a time.
lock_file = "/tmp/oott.lock"
File.open(lock_file, "a") {}
unless File.new(lock_file).flock( File::LOCK_NB | File::LOCK_EX )
  $stderr.puts "It appears another copy of this script is running and holds the lock on #{lock_file}.  Exiting."
  exit
end




api_client_ids.each do |one_client_id|
  if (api_secrets[one_client_id].to_s.length == 0)
    $stderr.puts "Invalid or missing api_client_secret for key id #{one_client_id}, skipping this key."
    $stderr.puts "The mode 600 file #{api_key_file} should contain one line per key ID/secret like:"
    $stderr.puts "myid1|mysecret1"
    $stderr.puts "myid2|mysecret2[|optional apihost:port]"
  else
    $stderr.puts "Pulling aspects from #{api_hosts[one_client_id]} using key #{one_client_id}"


    #If this script runs a long time, we'll need to get a new session key if
    #we're within a minute of the timeout.  Remember the timeout for later.
    #FIXME - get timeout from response instead of hardcoding
    revalidate_stamp = Time.now.to_i + 900

    #Acquire a session key from the Halo Portal for use by the rest of this script
    token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
    if token == ""
      $stderr.puts "Unable to retrieve a token, skipping account #{one_client_id}."
    else
      #Get the group name hash
      group_names = get_group_names(api_hosts[one_client_id],timeout,open_timeout,token)

      #Collect all aspects for all servers in this portal account in the following three
      thiskey_aspects = { }
      thiskey_aspect_scores = { }
      thiskey_server_ids = [ ]

      group_names.each_key do |one_group_id|
        group_servers_json = api_get("https://#{api_hosts[one_client_id]}/v1/groups/#{one_group_id}/servers",timeout,open_timeout,token)

        #Collect aspects for just the servers in this group in the following three
        aspects = { }
        aspect_scores = { }
        server_ids_to_process = [ ]

        group_servers_json['servers'].each do |one_server|
          server_hostnames[one_server['id']] = one_server['hostname']
          server_ids_to_process << one_server['id']
          thiskey_server_ids << one_server['id']
          global_server_ids << one_server['id']
          load_servers(aspects,aspect_scores,one_server,one_server['id'],parent_domain_cache)
          load_servers(thiskey_aspects,thiskey_aspect_scores,one_server,one_server['id'],parent_domain_cache)
          load_servers(global_aspects,global_aspect_scores,one_server,one_server['id'],parent_domain_cache)
        end

        server_ids_to_process.each do |one_id|
          issues_json = api_get("https://#{api_hosts[one_client_id]}/v1/servers/#{one_id}/issues",timeout,open_timeout,token)
          load_issues(aspects,aspect_scores,issues_json,one_id,status_scores)
          load_issues(thiskey_aspects,thiskey_aspect_scores,issues_json,one_id,status_scores)
          load_issues(global_aspects,global_aspect_scores,issues_json,one_id,status_scores)

          accounts_json = api_get("https://#{api_hosts[one_client_id]}/v1/servers/#{one_id}/accounts",timeout,open_timeout,token)
          load_accounts(aspects,aspect_scores,accounts_json,one_id,server_os)
          load_accounts(thiskey_aspects,thiskey_aspect_scores,accounts_json,one_id,server_os)
          load_accounts(global_aspects,global_aspect_scores,accounts_json,one_id,server_os)
        end

        #This creates the report for just this server group
        print_oott_report(one_client_id+"-"+group_names[one_group_id],aspects,aspect_scores,server_ids_to_process,server_hostnames,report_dir,group_servers_json['servers'].length,table_names,server_os)

        #If this script runs a long time, we'll need to get a new session key if
        #we're within a minute of the timeout
        if ( Time.now.to_i > ( revalidate_stamp - 60 ) )
          #FIXME - get timeout from response instead of hardcoding
          revalidate_stamp = Time.now.to_i + 900

          #Acquire a new session key from the Halo Portal
          token = get_auth_token(one_client_id,api_secrets[one_client_id],my_proxy,api_hosts[one_client_id])
          if token == ""
            $stderr.puts "Unable to retrieve a token, exiting."
            exit 1
          end
        end #We needed to get a new token

      end #loop through each group

      #Now that we've processed each group we do the report for all servers in this portal account
      print_oott_report(one_client_id+"-Combined list of all servers",thiskey_aspects,thiskey_aspect_scores,thiskey_server_ids,server_hostnames,report_dir,thiskey_server_ids.length,table_names,server_os)

    end #we have a valid token
  end #we have a valid secret
end #loop through the client ids
$stderr.puts "Complete."

#If more than one portal account was polled,
if api_client_ids.length > 1
  #print the report for all servers we've seen in all portal accounts
  print_oott_report(api_client_ids.join("-")+"-Combined list of all servers",global_aspects,global_aspect_scores,global_server_ids,server_hostnames,report_dir,server_hostnames.length,table_names,server_os)
end

$stderr.puts $all_warnings.values

exit 0


