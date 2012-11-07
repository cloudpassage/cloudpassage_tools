#!/bin/sh
#
# set up /etc/hosts autogen stuff
#

# grab the template hosts file that we can add onto
if [ ! -f /etc/hosts.template ] ; then
    cp /etc/hosts /etc/hosts.template
fi

# set up cron
cp hostsupdate.cron /etc/cron.d/hostsupdate

# install the script
mkdir -p /usr/local/bin
cp hosts.rb > /usr/local/bin/hosts.rb
chmod 700 /usr/local/bin/hosts.rb

