#!/bin/bash -xv

realpath "$0"

# Install software
apt-get -qqy --no-install-recommends -o=Dpkg::Use-Pty=0 install stubby dnsmasq dnsutils

# Stubby coniguration
cat > /etc/stubby/stubby.yml << EOF
resolution_type: GETDNS_RESOLUTION_STUB

dns_transport_list:
  - GETDNS_TRANSPORT_TLS

tls_authentication: GETDNS_AUTHENTICATION_REQUIRED

tls_query_padding_blocksize: 128

edns_client_subnet_private : 1

round_robin_upstreams: 1

idle_timeout: 10000

listen_addresses:
  - 127.0.0.1@53000

appdata_dir: "/var/cache/stubby"

upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"
  - address_data: 1.0.0.1
    tls_auth_name: "cloudflare-dns.com"

  - address_data: 2606:4700:4700::1111
    tls_auth_name: "cloudflare-dns.com"
  - address_data: 2606:4700:4700::1001
    tls_auth_name: "cloudflare-dns.com"
EOF

# dnsmasq configuration
cat > /etc/dnsmasq.conf <<EOF
no-resolv
proxy-dnssec
server=127.0.0.1#53000
listen-address=127.0.0.1,$IP
EOF

systemctl -q enable stubby dnsmasq