#!/bin/bash -xv

#TODO:
# unattended upgrade
# duplicati
# ufw
# mfa: #libmicrohttpd12 #libpam-google-authenticator
# motion
# samba samba-common-bin
# Enable syslog TCP for fluent-bit https://pimylifeup.com/raspberry-pi-syslog-server/

touch /boot/ssh

# Disable mouse mode in Vim
echo "" >> /etc/vimrc
cat >> /etc/vimrc << EOF
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

# Can we make it completely passwordless instead of a random 60 char passphrase?
echo "$USERNAME:$(head -n 60 < /dev/urandom | tr -d '\n' | openssl passwd -6 -stdin)" >> /boot/userconf.txt

mv /home/pi /home/uno

useradd uno
groupadd wheel
usermod -a -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,wheel uno
deluser pi

echo "%wheel         ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers

mkdir /home/$USERNAME/.ssh

sed -i 's/[#]PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add Fluent Bit repository
wget -qO - https://packages.fluentbit.io/fluentbit.key | sudo apt-key add -
echo "deb https://packages.fluentbit.io/raspbian/bullseye bullseye main" >> /etc/apt/sources.list

apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install vim jc cockpit cockpit-pcp stubby dnsmasq fluent-bit network-manager-openvpn

# OpenVPN
nmcli connection import type openvpn file /azure.ovpn
nmcli connection modify AzureVPN ipv4.never-default true
nmcli connection up AzureVPN
rm /azure.ovpn

# Fluent-bit configuration
sed -i 's/\[Service\]/\[Service\]\nEnvironmentFile=\/etc\/azurelaconfig/' /lib/systemd/system/fluent-bit.service
echo -e "WORKSPACE_ID=$WORKSPACE_ID" > /etc/azurelaconfig
echo -e "WORKSPACE_KEY=$WORKSPACE_KEY" >> /etc/azurelaconfig

# Stubby coniguration
#uncomment Cloudflare in stubby.yml
#also add @53000 as port to listen addresses
#comment all the others

# dnsmasq configuration
#/etc/dnsmasq.conf:
#no-resolv
#proxy-dnssec
#server=::1#53000
#server=127.0.0.1#53000
#listen-address=::1,127.0.0.1,$IP

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

echo "$HOSTNAME" > /etc/hostname
sed "s/^127.0.0.1[ \t]*raspberrypi/127.0.0.1 $HOSTNAME/" /etc/hosts

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i '/^session[ \t]*optional[ \t]*pam_motd.so.*/d' /etc/pam.d/login

systemctl -q enable ssh
systemctl -q enable fluent-bit
systemctl -q enable stubby
systemctl -q enable dnsmasq

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