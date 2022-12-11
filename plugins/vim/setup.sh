#!/bin/bash -xv

# Install software
apt-get -qqy --no-install-recommends install vim

# Disable mouse mode in Vim
echo "" >> /etc/vim/vimrc
cat >> /etc/vim/vimrc << EOF
set mouse=
set ttymouse=
EOF