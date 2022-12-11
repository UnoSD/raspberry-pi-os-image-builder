#!/bin/bash -xv

#TODO:
# unattended upgrade
# duplicati
# ufw
# mfa: #libmicrohttpd12 #libpam-google-authenticator
# motion
# samba samba-common-bin
# Enable syslog TCP for fluent-bit https://pimylifeup.com/raspberry-pi-syslog-server/
# BATCH FLUENT-BIT OUTPUTS, SO IT SENDS EVERY 1/2 minute but with per-second data (so reduce to second for slower stuff)

# Enable SSH, probably useless given I enable it with systemd below
touch /boot/ssh

# Disable mouse mode in Vim
echo "" >> /etc/vim/vimrc
cat >> /etc/vim/vimrc << EOF
set mouse=
set ttymouse=
EOF

# Set time zone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

# Enable PagUp/PagDown to search history
sed -i '/# "\\e\[5~": history-search-backward/s/^# //g' /etc/inputrc
sed -i '/# "\\e\[6~": history-search-forward/s/^# //g' /etc/inputrc

# Enable bash completion globally
echo "" >> /etc/bash.bashrc
cat >> /etc/bash.bashrc <<EOF
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF

# Set user passphrase
# Can we make it completely passwordless instead of a random 60 char passphrase?
echo "$USERNAME:$(head -n 60 < /dev/urandom | tr -d '\n' | openssl passwd -6 -stdin)" >> /boot/userconf.txt

# Remove default user and add custom
mv /home/pi /home/$USERNAME
useradd $USERNAME
groupadd wheel
usermod -a -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,wheel $USERNAME
groupdel pi
deluser pi

# Add wheel group to no password sudo
echo "%wheel         ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set up ssh and disable password
mkdir /home/$USERNAME/.ssh
sed -i 's/[#]PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add Fluent Bit repository
wget -qO - https://packages.fluentbit.io/fluentbit.key | gpg --dearmor > /usr/share/keyrings/fluentbit.key
echo "deb [signed-by=/usr/share/keyrings/fluentbit.key] https://packages.fluentbit.io/raspbian/bullseye bullseye main" >> /etc/apt/sources.list

# Install software
apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install \
  vim \
  jc \
  cockpit \
  cockpit-pcp \
  stubby \
  dnsmasq \
  fluent-bit \
  openvpn \
  unattended-upgrades \
  dnsutils

# Set up OpenVPN
mv /tmp/azure.conf /etc/openvpn/client/
systemctl -q enable openvpn-client@azure.service

# Fluent-bit configuration
sed -i 's/\[Service\]/\[Service\]\nEnvironmentFile=\/etc\/azurelaconfig/' /lib/systemd/system/fluent-bit.service
echo -e "WORKSPACE_ID=$WORKSPACE_ID" > /etc/azurelaconfig
echo -e "WORKSPACE_KEY=$WORKSPACE_KEY" >> /etc/azurelaconfig

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

# Unattended upgrades (wrong files, WIP)
cat > /etc/auto_upgrade <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "3";
APT::Periodic::Verbose "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
cat > /etc/unattended_upgrade <<EOF
// The Raspberry Pi Foundation doesn't use separate a separate security upgrades channel.
// To make sure your RPi has the latest security fixes, you have to install all updates.

Unattended-Upgrade::Origins-Pattern {
        "origin=Raspbian,codename=${distro_codename},label=Raspbian";
        "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";
};

// Automatically reboot *WITHOUT CONFIRMATION* if
//  the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "true";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//  Default: "now"
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

# Update Private DNS zone on connect
##!/bin/bash
## Save to /etc/network/if-up.d/
#if [[ "$IFACE" =~ ^(tun|vpn)[0-9] ]]; then
#    # On VPN connection, update Private DNS Zone
#    # az network private-dns record-set a show -g RESOURCEGROUP -z ZONENAME -n $HOSTNAME -o jsonc
#    # remove record
#    # add correct record
#    su uno -c 'az cli .....'
#fi

rm -f /etc/motd
rm -f /etc/motd.d/*

echo "$HOSTNAME" > /etc/hostname
sed -i "s/^127.0.0.1[ \t]*raspberrypi/127.0.0.1 $HOSTNAME/" /etc/hosts

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i '/^session[ \t]*optional[ \t]*pam_motd.so.*/d' /etc/pam.d/login

systemctl -q enable ssh fluent-bit stubby dnsmasq

# Set up static network addresses if supplied
if [[ -n ${IP} && -n ${SUBNET} && -n ${GATEWAY} ]]; then

    cat > /etc/dhcpcd.conf <<EOF
interface eth0
static ip_address=$IP/$SUBNET
static routers=$GATEWAY
static domain_name_servers=1.1.1.1 1.0.0.1

interface wlan0
static ip_address=$IP/$SUBNET
static routers=$GATEWAY
static domain_name_servers=1.1.1.1 1.0.0.1
EOF

fi