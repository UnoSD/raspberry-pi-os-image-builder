#!/bin/bash -xv

realpath "$0"

# Install software
apt-get -qqy --no-install-recommends -o=Dpkg::Use-Pty=0 install openvpn

# Set up OpenVPN
mv /tmp/azure.conf /etc/openvpn/client/
systemctl -q enable openvpn-client@azure.service

# Is this using the VPN only for VPN routes??