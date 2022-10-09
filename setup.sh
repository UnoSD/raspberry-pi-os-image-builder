#!/bin/bash

wpa_passphrase "$SSID" "$WIFI_PASSWORD" | sed -e 's/#.*$//' -e '/^$/d' >> /etc/wpa_supplicant/wpa_supplicant.conf

touch /boot/ssh

# Can we make it completely passwordless instead of a random 60 char passphrase?
echo "$USERNAME:$(echo "Password1!" | openssl passwd -6 -stdin)" >> /boot/userconf.txt

mv /home/pi /home/uno

useradd uno
usermod -a -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi uno
deluser pi

mkdir /home/$USERNAME/.ssh

sed -i 's/[#]PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

apt-get -qq update && apt-get -qqy upgrade

rm -f /etc/motd

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i '/^session[ \t]*optional[ \t]*pam_motd.so.*/d' /etc/pam.d/login

systemctl -q enable ssh

if [[ -n ${IP} && -n ${SUBNET} && -n ${ROUTER} ]]; then

    cat > /etc/dhcpd.conf <<EOF
interface eth0
static ip_address=$IP/$SUBNET
static routers=$ROUTER
static domain_name_servers=1.1.1.1 1.0.0.1

interface wlan0
static ip_address=$IP/$SUBNET
static routers=$ROUTER
static domain_name_servers=1.1.1.1 1.0.0.1
EOF

fi