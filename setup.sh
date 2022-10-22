#!/bin/bash

#TODO:
# ufw
# mfa: #libmicrohttpd12 #libpam-google-authenticator
# motion
# samba samba-common-bin

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

apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install vim jc cockpit cockpit-pcp

# Fluent-bit
# sed -i 's/\[Service\]/\[Service\]\nEnvironmentFile=\/etc\/azurelaconfig/' /lib/systemd/system/fluent-bit.service
# echo -e "WORKSPACE_ID={LA WID}" > /etc/azurelaconfig
# echo -e "WORKSPACE_KEY={LA KEY}" >> /etc/azurelaconfig

rm -f /etc/motd

echo "$HOSTNAME" > /etc/hostname
sed "s/^127.0.0.1[ \t]*raspberrypi/127.0.0.1 $HOSTNAME/" /etc/hosts

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i '/^session[ \t]*optional[ \t]*pam_motd.so.*/d' /etc/pam.d/login

systemctl -q enable ssh

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