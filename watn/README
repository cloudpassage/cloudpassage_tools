Where Are They Now?

	This script provides an html-formatted page showing the IP
addresses from which Halo Portal users have logged in.  Reviewing this
report allows you to quickly identify logins from suspcious networks
unexpected countries, or at unusual times of day.

Requirements:
- ruby
- The following ruby gems installed: oauth2, rest-client, json, public_suffix,
  optparse, resolv, date, and ip.  The following command will install all
  optional gems needed by the CloudPasssage API clients:
  sudo gem install oauth2 rest-client json public_suffix ip
- A Read only (preferred) or Full access API key and secret (*), placed in 
  /etc/halo-api-keys separated by a vertical pipe, like:
aa00bb44|11111111222222223333333344444444
  This file should be owned by the user that runs api scripts, mode 600.
  Developers only: If you're working with an alternate grid, put that 
  grid's api hostname and port in the third column of the line:
aa00bb44|11111111222222223333333344444444|api.example.com:9999

* These can be found in the Portal under Settings, Site Administration, 
  API Keys.

Installation:
- Copy where-are-they-now.rb and wlslib.rb to the same directory in your path. 
wlslib.rb will also be found if you copy it to any directory in your
ruby library search path, which can be seen by running
echo 'puts $:' | irb
- Make a directory to hold a local copy of events with:
mkdir -m 700 ~/api_cache/
- [Optional but recommended] Create a file holding IP addresses and/or
  CIDR blocks that you're confident are legitimate source addresses. 
  Any logins from one of these will show in a "verified" column for the
  output, allowing you to focus on the "unverified" addresses.
touch /etc/verified-client-ips
chmod 600 /etc/verified-client-ips
chown {user} /etc/verified-client-ips
(where "{user}" is the user under which these scripts will be run.
{Edit this file and add any verified addresses}


Sample invocations:

#See help text and parameters:
where-are-they-now.rb -h

#Generate a login IP report and save to disk
where-are-they-now.rb -i aabbcc00 >watn-report.html

#Generate a report but only cover logins since 2013-01-15
where-are-they-now.rb -i aabbcc00 -s 201301015 >watn-report-recent.html





Advanced uses:

#If you manage more than one Halo Portal organization, you can generate
#a report that covers logins from all of them by specifying "-i {key}"
#multiple times (with corresponding lines for all keys in
#/etc/halo-api-keys :
where-are-they-now.rb -i aabbcc00 -i 7890abcd >watn-combined.html
