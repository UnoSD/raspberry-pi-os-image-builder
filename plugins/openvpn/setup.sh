#!/bin/bash -xv

# Install software
apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install openvpn

# Set up OpenVPN
mv /tmp/azure.conf /etc/openvpn/client/
systemctl -q enable openvpn-client@azure.service