#!/bin/bash

# Create the directory for combined certs if it doesn't exist
mkdir -p /etc/letsencrypt/haproxy

# Iterate over all certificate directories
for d in /etc/letsencrypt/live/*; do
  if [ -d "$d" ]; then
    domain=$(basename "$d")
    echo "Combining certs for $domain..."
    cat "$d/fullchain.pem" "$d/privkey.pem" > "/etc/letsencrypt/haproxy/$domain.pem"
  fi
done

# Reload HAProxy to pick up new certs if running
if pidof haproxy > /dev/null; then
    echo "Reloading HAProxy..."
    kill -HUP $(pidof haproxy)
fi

echo "Certificates combined and HAProxy reloaded."