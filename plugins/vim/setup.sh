#!/bin/bash -xv

# Install software
apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install vim

# Disable mouse mode in Vim
echo "" >> /etc/vim/vimrc
cat >> /etc/vim/vimrc << EOF
set mouse=
set ttymouse=
EOF