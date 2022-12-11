#!/bin/bash -xv

# Add Fluent Bit repository
wget -qO - https://packages.fluentbit.io/fluentbit.key | gpg --dearmor > /usr/share/keyrings/fluentbit.key
echo "deb [signed-by=/usr/share/keyrings/fluentbit.key] https://packages.fluentbit.io/raspbian/bullseye bullseye main" >> /etc/apt/sources.list

# Install software
apt-get -qq update && apt-get -qqy --no-install-recommends install fluent-bit

# Fluent-bit configuration
sed -i 's/\[Service\]/\[Service\]\nEnvironmentFile=\/etc\/azurelaconfig/' /lib/systemd/system/fluent-bit.service
echo -e "WORKSPACE_ID=$WORKSPACE_ID" > /etc/azurelaconfig
echo -e "WORKSPACE_KEY=$WORKSPACE_KEY" >> /etc/azurelaconfig

mv /tmp/plugins/fluent-bit/fluent-bit.conf /etc/fluent-bit/fluent-bit.conf

systemctl -q enable fluent-bit