	This script downloads all the FIM and firewall policies
contained in one or more Halo Portal accounts.  As of this writing, it
does not support downloading Configuration policies.

Requirements:
- ruby
- The following ruby gems installed: oauth2, rest-client, json, date, 
  and optparse.  The following command will install all
  optional gems needed by the CloudPasssage API clients:
  sudo gem install oauth2 rest-client json public_suffix ip
- A Read only (preferred) or Full access API key and secret , placed in 
  /etc/halo-api-keys separated by a vertical pipe, like:
aa00bb44|11111111222222223333333344444444
  This file should be owned by the user that runs api scripts, mode 600.
  Developers only: If you're working with an alternate grid, put that 
  grid's api hostname and port in the third column of the line:
aa00bb44|11111111222222223333333344444444|api.example.com:9999

Installation:
- Copy archive-policies.rb and wlslib.rb to the same directory in your path.
wlslib.rb will also be found if you copy it to any directory in your
ruby library search path, which can be seen by running
echo 'puts $:' | irb


Sample invocations:

#See help text and parameters:
archive-policies.rb -h

#Download all fim and firewall policies to the current directory:
archive-policies.rb -i ab45fe98

#Download all fim and firewall policies to a different directory, which must already exist:
archive-policies.rb -i ab45fe98 --report_dir /var/tmp/downloads/
