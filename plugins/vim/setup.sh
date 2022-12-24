#!/bin/bash -xv

realpath "$0"

# Install software
apt-get -qqy --no-install-recommends -o=Dpkg::Use-Pty=0 install vim

# Disable mouse mode in Vim
echo "" >> /etc/vim/vimrc
cat >> /etc/vim/vimrc << EOF
set mouse=
set ttymouse=
EOF