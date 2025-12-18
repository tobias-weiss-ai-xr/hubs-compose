the ha proxy needs to be more graceful, if letsenrypt cert cannot be obtained:


haproxy  | - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
haproxy  | Certificate not yet due for renewal; no action taken.
haproxy  | - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
haproxy  | Saving debug log to /var/log/letsencrypt/letsencrypt.log
haproxy  | Plugins selected: Authenticator standalone, Installer None
haproxy  | Requesting a certificate for tobias-weiss.org
haproxy  | Performing the following challenges:
haproxy  | http-01 challenge for tobias-weiss.org
haproxy  | Waiting for verification...
haproxy  | Challenge failed for domain tobias-weiss.org
haproxy  | http-01 challenge for tobias-weiss.org
haproxy  | Cleaning up challenges
haproxy  | Some challenges have failed.
haproxy  | IMPORTANT NOTES:
haproxy  |  - The following errors were reported by the server:
haproxy  |
haproxy  |    Domain: tobias-weiss.org
haproxy  |    Type:   unauthorized
haproxy  |    Detail: 178.254.31.104: Invalid response from
haproxy  |    https://tobias-weiss.org/.well-known/acme-challenge/32FE5_WXAEphQQku-ClRvRNHImHhOllYj22Ojbu89B0:
haproxy  |    404
haproxy  |
haproxy  |    To fix these errors, please make sure that your domain name was
haproxy  |    entered correctly and the DNS A/AAAA record(s) for that domain
haproxy  |    contain(s) the right IP address.