#!/bin/bash
# LetsEncrypt auto-renew script by BhaaL (2016-01-30)
# requires a CLI config for every domain
#
# == Configuration ==
# Delta time before renewal
MAX_DAYS_UNTIL_EXPIRE=10
# Folder containing config files
CONFIG_DIRECTORY=/home/letsencrypt/configs/
# Folder containing LetsEncrypt cert files
LETSENCRYPT_LIVE=/etc/letsencrypt/live/
# LetsEncrypt executable (letsencrypt, not letsencrypt-auto)
LETSENCRYPT_BIN=/root/.local/share/letsencrypt/bin/letsencrypt
# Command to restart the web server
RESTART_WEBSERVER="apache2ctl graceful"
# == End of Configuration ==
# I suggest you don't change anything beyond this point.

function do_renew() {
        config_file=$1
        # grab the "domains = foo.tld,www.foo.tld" line and extract the first domain
        # then trim all excess whitespace
        target_domain=$(grep '^domains' $config_file | cut -d'=' -f2 | cut -d',' -f1 | tr -d '[[:space:]]')
        # check if that first domain exists as cert; if not simply assume
        # it is a new cert
        target_cert="$LETSENCRYPT_LIVE/$target_domain/cert.pem"
        # assume we want to renew by default
        should_renew=1
        if [ -f $target_cert ]; then
                expires_at=$(date -d "`openssl x509 -in $target_cert -text -noout | grep 'Not After' | cut -c 25-`" +%s)
                today=$(date -d "now" +%s)
                expires_in_days=$(( ( $expires_at - $today ) / ( 60 * 60 * 24 ) ))

                # are we close to expiry? if not, skip this one
                if [ $expires_in_days -gt $MAX_DAYS_UNTIL_EXPIRE ]; then
                        should_renew=0
                fi;
        fi;

        if [ $should_renew -eq 1 ]; then
                $LETSENCRYPT_BIN auth -c $config_file
        fi;

        # return a status on whether renewal was attempted or not
        return $should_renew
}

# how many certs have been updated (or...attempted to)
updated_certs=0
for cfg in $(ls -1 $CONFIG_DIRECTORY/*.ini); do
        do_renew $cfg
        updated_certs=$(($updated_certs + $?))
done;

# has anything updated? restart web server
if [ $updated_certs -gt 0 ]; then
        $RESTART_WEBSERVER
fi;

exit
