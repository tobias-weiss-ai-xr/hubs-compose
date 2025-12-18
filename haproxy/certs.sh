#!/usr/bin/env bash

# Function to generate self-signed cert
generate_self_signed() {
    local domain=$1
    echo "Generating self-signed certificate for $domain..."
    # Ensure the directory exists (Certbot creates it, but we might be first or it might have failed early)
    mkdir -p "/etc/letsencrypt/live/$domain"
    
    # Generate key and cert if they don't exist or if we want to overwrite
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "/etc/letsencrypt/live/$domain/privkey.pem" \
        -out "/etc/letsencrypt/live/$domain/fullchain.pem" \
        -subj "/CN=$domain"
}

if [ -n "$CERT1" ] || [ -n "$CERT" ]; then
    
    # Iterate over CERT variables
    # We sort them to ensure consistent processing order, though not strictly required
    for certname in $(compgen -v | grep '^CERT' | sort); do
        domain=${!certname}
        echo "----------------------------------------------------------------"
        echo "Processing certificate for: $domain"

        # Try Certbot
        if [ "$STAGING" = true ]; then
             certbot certonly --no-self-upgrade -n --text --standalone \
            --preferred-challenges http-01 \
            --staging \
            -d "$domain" --keep --expand --agree-tos --email "$EMAIL"
        else
             certbot certonly --no-self-upgrade -n --text --standalone \
            --preferred-challenges http-01 \
            -d "$domain" --keep --expand --agree-tos --email "$EMAIL"
        fi

        exit_code=$?

        if [ $exit_code -ne 0 ]; then
            echo "WARNING: Certbot failed for $domain (Exit code: $exit_code)."
            echo "Falling back to self-signed certificate for $domain."
            generate_self_signed "$domain"
        else
            echo "Certbot successfully obtained/renewed certificate for $domain."
        fi
    done

    # Prepare HAProxy certs directory
    mkdir -p /etc/haproxy/certs

    # Bundle certificates for HAProxy
    # We iterate over the live directory to catch both Certbot and self-signed certs
    echo "Bundling certificates for HAProxy..."
    for site in `ls -1 /etc/letsencrypt/live | grep -v ^README$`; do
        if [ -f "/etc/letsencrypt/live/$site/privkey.pem" ] && [ -f "/etc/letsencrypt/live/$site/fullchain.pem" ]; then
            echo " - Bundling $site"
            cat "/etc/letsencrypt/live/$site/privkey.pem" \
                "/etc/letsencrypt/live/$site/fullchain.pem" \
                | tee "/etc/haproxy/certs/haproxy-$site.pem" >/dev/null
        else
            echo "SKIPPING $site: Missing key or fullchain file."
        fi
    done
fi

exit 0
