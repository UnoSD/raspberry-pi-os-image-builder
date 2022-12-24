#!/bin/bash -xv

realpath "$0"

# Install software
apt-get -qqy --no-install-recommends -o=Dpkg::Use-Pty=0 install cockpit cockpit-pcp