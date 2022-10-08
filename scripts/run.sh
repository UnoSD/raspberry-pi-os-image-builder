#!/usr/bin/env sh

touch /boot/ssh
#echo "$USERNAME:PASSWORD" >> /boot/userconf.txt
mkdir /home/$USERNAME/.ssh
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh

sed '/PasswordAuthentication/d' -i /etc/ssh/sshd_config
echo >> /etc/ssh/sshd_config
echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config

echo nameserver 1.1.1.1 > /etc/resolv.conf

apt-get update
apt-get -y install --no-install-recommends curl

rm -f /etc/motd

chown $USERNAME:$USERNAME -R /home/$USERNAME/

sed -i 's/^session[ \t]*optional[ \t]*pam_motd.so[ /t]*motd=\/run\/motd.dynamic/#session optional pam_motd.so motd=\/run\/motd.dynamic/' /etc/pam.d/login
sed -i 's/^session[ \t]*optional[ \t]*pam_motd.so[ /t]*noupdate/#session optional pam_motd.so noupdate/' /etc/pam.d/login

systemctl enable ssh
systemctl enable getty@
