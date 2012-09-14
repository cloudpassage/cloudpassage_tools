#!/bin/sh
#
# set up /etc/hosts autogen stuff
#
# You will need to set CLOUDPASSAGE_API_KEY somehow.  We do this using
# RightScale.
#

if [ -z "$CLOUDPASSAGE_API_KEY" ] ; then
	echo CLOUDPASSAGE_API_KEY not set:  exiting
	exit 1
fi

# grab the template hosts file that we can add onto
if [ ! -f /etc/hosts.template ] ; then
    cp /etc/hosts /etc/hosts.template
fi

# set up cron
cp hostsupdate.cron /etc/cron.d/hostsupdate

# install the script
mkdir -p /usr/local/bin
sed "s/XXXAPIKEYXXX/$CLOUDPASSAGE_API_KEY/" < hosts.rb > /usr/local/bin/hosts.rb
chmod 700 /usr/local/bin/hosts.rb

