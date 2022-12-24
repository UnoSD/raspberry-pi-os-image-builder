#!/bin/bash -xv

# Enable SSH, probably useless given I enable it with systemd below
touch /boot/ssh

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

# Install software
apt-get -qq update && apt-get -qqy -o=Dpkg::Use-Pty=0 upgrade && apt-get -qqy --no-install-recommends install jc -o=Dpkg::Use-Pty=0

rm -f /etc/motd
rm -f /etc/motd.d/*

echo "$HOSTNAME" > /etc/hostname
#sed -i "s/^127.0.0.1[ \t]*raspberrypi/127.0.0.1 $HOSTNAME/" /etc/hosts
echo "127.0.0.1 $HOSTNAME" > /etc/hosts

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

tr " " "\n" <<<"$EXCLUDE_PLUGINS" >> /tmp/exclude-plugins

find /tmp/plugins -name setup.sh | grep -vf /tmp/exclude-plugins | xargs -n1 bash