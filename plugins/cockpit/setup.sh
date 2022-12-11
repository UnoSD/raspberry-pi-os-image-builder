#!/bin/bash -xv

# Install software
apt-get -qq update && apt-get -qqy upgrade && apt-get -qqy --no-install-recommends install cockpit cockpit-pcp