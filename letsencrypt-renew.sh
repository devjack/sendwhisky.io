
#!/bin/bash

HOSTNAME=$( cut -d ',' -f 1 <<< "$LE_DOMAIN" )
EXPIRE_THRESHOLD=$((86400 * 30)) #30 days


function lebot() {
    if hash letsencrypt 2>/dev/null; then
        letsencrypt "$@"
    elif hash certbot 2>/dev/null; then
        certbot "$@"
    else
        echo >&2 "letsencrypt was not found in any of its forms. Aborting."; exit 1;
    fi
}


echo "" | openssl s_client -connect $HOSTNAME:443 -servername $HOSTNAME -prexit 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' | openssl x509 -checkend $EXPIRE_THRESHOLD -noout

if [ $? -ne 0 ]
then
  echo "Certificate is good for another day!"
else
  echo "Certificate has expired, or will soon (or there was an error)!"
  echo "Attempting certificate renewal"

  lebot --agree-tos -a letsencrypt-s3front:auth \
     --letsencrypt-s3front:auth-s3-bucket $S3_BUCKET \
     --letsencrypt-s3front:auth-s3-region $S3_REGION \
     -i letsencrypt-s3front:installer \
     --letsencrypt-s3front:installer-cf-distribution-id $CF_DISTRIBUTION \
     -d $(echo ${LE_DOMAIN//,/ -d }) \
    -m $LE_EMAIL \
     --renew-by-default --text \
    --work-dir ./le/work \
    --cert-path ./le/cert \
    --key-path ./le/key \
    --config-dir ./le/config \
    --logs-dir ./le/logs
fi
