#!/bin/bash -xv

realpath "$0"

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

# Generate cert in Pulumi and Packer copy to /etc/ssl/motion and publish /etc/ssl/motion/motion.pem
# or in image.pkr.hcl:
#    provisioner "file" {
#        source      = "/etc/ssl/motion/motion.pem"
#        destination = "motion.pem"
#        direction   = "download"
#    }
mkdir /etc/ssl/motion
cd /etc/ssl/motion
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout motion.key -outform pem -out motion.pem -subj "/CN=${HOSTNAME}"

apt-get -qqy --no-install-recommends -o=Dpkg::Use-Pty=0 install motion sshfs

envsubst /tmp/plugins/cctv/motion.conf > /etc/motion/motion.conf

mkdir /var/{log,run}/motion

mkdir $TARGET_DIR

chown motion:motion /etc/ssh/ssh_motion $TARGET_DIR /var/{log,run}/motion

systemctl -q enable motion

echo "$STORAGE_ACCOUNT_NAME.motion.$STORAGE_USERNAME@$STORAGE_ACCOUNT_NAME.blob.core.windows.net:/ /mnt/blobsftp fuse.sshfs user,idmap=user,follow_symlinks,identityfile=/etc/ssh/ssh_motion,allow_other,default_permissions,x-systemd.automount,x-systemd.mount-timeout=30,x-systemd.idle-timeout=0,reconnect,_netdev,uid=$(id -u motion),gid=$(id -g motion) 0 0" >> fstab