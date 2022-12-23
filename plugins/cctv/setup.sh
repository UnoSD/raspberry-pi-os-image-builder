#!/bin/bash -xv

# Use blob sftp and event grid to trigger alarm

# Optimize codec to reduce CPU usage: https://wiki.gentoo.org/wiki/Motion#Video_codec
# Send logs to database: https://wiki.gentoo.org/wiki/Motion#Database

# Play with basic auth
# mpv --no-cache http://hostname:port --untimed --no-demuxer-thread --title="Camera 1" --http-header-fields="Authorization: Basic $(echo -n 'username:password' | base64)"
# mpv --no-cache http://username:password@hostname:port --untimed --no-demuxer-thread --title="Camera 1"

# Play with digest authentication
# curl http://hostname:port --digest -u username:password --output - | mpv --no-cache --untimed --no-demuxer-thread --title="Camera 1" -

# Pass those as arguments
TARGET_DIR=/mnt/blobsftp
WEBCONTROL_CERT=/etc/ssl/motion/motion.pem
WEBCONTROL_KEY=/etc/ssl/motion/motion.key
USERNAME=$USERNAME
PASSWORD=$MOTION_PASSWORD
HOSTNAME=$HOSTNAME

mkdir /etc/ssl/motion
cd /etc/ssl/motion
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout motion.key -outform pem -out motion.pem -subj "/CN=${HOSTNAME}"

# PACKER COPY /etc/ssl/motion/motion.pem TO HOST
# AZDO PUBLISH ARTIFACT

apt-get -qqy --no-install-recommends install motion sshfs

envsubst /tmp/plugins/cctv/motion.conf > /etc/motion/motion.conf

mkdir /var/{log,run}/motion

chown motion:motion /var/{log,run}/motion

systemctl -q enable motion

# FROM PULUMI: pulumi stack output PrivateKey --show-secrets > pk
#mkdir $TARGET_DIR
# get uid e pid of motion and set below
#ACCOUNT.motion.uno@ACCOUNT.blob.core.windows.net:/ /mnt/blobsftp fuse.sshfs user,idmap=user,follow_symlinks,identityfile=/home/uno/pk,allow_other,default_permissions,x-systemd.automount,x-systemd.mount-timeout=30,x-systemd.idle-timeout=0,reconnect,_netdev,uid=110,gid=114 0 0