#!/bin/bash

# ADD PAGUP TO RECALL COMMAND
# bash completion
#time zone
#vim no mouse mode
#Try cockpit and Log Analytics
# install ufw
# optional mfa:
#libmicrohttpd12
#libpam-google-authenticator
#motion
#samba samba-common-bin
#ufw

# sed -i 's/\[Service\]/\[Service\]\nEnvironmentFile=\/etc\/azurelaconfig/' /lib/systemd/system/fluent-bit.service
# echo -e "WORKSPACE_ID={LA WID}" > /etc/azurelaconfig
# echo -e "WORKSPACE_KEY={LA KEY}" >> /etc/azurelaconfig

touch /boot/ssh

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

apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy install vim jc

rm -f /etc/motd

echo "$HOSTNAME" > /etc/hostname
sed "s/^127.0.0.1[ \t]*raspberrypi/127.0.0.1 $HOSTNAME/" /etc/hosts

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i '/^session[ \t]*optional[ \t]*pam_motd.so.*/d' /etc/pam.d/login

systemctl -q enable ssh

if [[ -n ${IP} && -n ${SUBNET} && -n ${ROUTER} ]]; then

    cat > /etc/dhcpcd.conf <<EOF
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