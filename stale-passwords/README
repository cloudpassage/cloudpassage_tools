	This script looks at all Halo-secured systems in a single portal
account and reports on all server-local accounts whose passwords have
not been changed in over M days (where M is specified on the command
line).

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
- Copy stale-passwords.rb and wlslib.rb to the same directory in your path.
wlslib.rb will also be found if you copy it to any directory in your
ruby library search path, which can be seen by running
echo 'puts $:' | irb


Sample invocations:

#See help text and parameters:
stale-passwords.rb -h

#List all non-system accounts whose passwords have not been changed in the last 90 days:
stale-passwords.rb -m 90 -i ab45fe98 --nosys

#As above, but only show the actual lines, no headers:
stale-passwords.rb -m 90 -i ab45fe98 --nosys 2>/dev/null

#As above, but pipe output only to another script:
stale-passwords.rb -m 90 -i ab45fe98 --nosys | process_stale_passwords ...

#Save to disk for later processing, such as importing into a database or spreadsheet
stale-passwords.rb -m 90 -i ab45fe98 --nosys >stale-password-accounts.csv
