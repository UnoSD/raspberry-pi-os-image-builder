#!/usr/bin/env sh

touch /boot/ssh
# Can we make it completely passwordless instead of a random 60 char passphrase?
echo "$USERNAME:$(head -n 60 < /dev/urandom | tr -d '\n' | openssl passwd -6 -stdin)" >> /boot/userconf.txt
mkdir /home/$USERNAME/.ssh
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh

sed '/PasswordAuthentication/d' -i /etc/ssh/sshd_config
echo -e "\nPasswordAuthentication no" >> /etc/ssh/sshd_config

echo nameserver 1.1.1.1 > /etc/resolv.conf

apt-get update
apt-get -y install --no-install-recommends curl

rm -f /etc/motd

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i 's/^session[ \t]*optional[ \t]*pam_motd.so[ /t]*motd=\/run\/motd.dynamic/#session optional pam_motd.so motd=\/run\/motd.dynamic/' /etc/pam.d/login
sed -i 's/^session[ \t]*optional[ \t]*pam_motd.so[ /t]*noupdate/#session optional pam_motd.so noupdate/' /etc/pam.d/login

systemctl -q enable ssh
systemctl -q enable getty@

cat > /etc/dhcpd.conf <<EOF
interface eth0
static ip_address=$IP/$SUBNET
static routers=$ROUTER
static domain_name_servers=1.1.1.1 1.0.0.1
EOF