#!/bin/sh

set -e

YUM="yum --assumeyes --enablerepo=epel"
UDO="sudo -u app"

$YUM install libevent-devel
sudo python-pip install virtualenv

# Install loads from github master.

cd /home/app
$UDO git clone https://github.com/mozilla-services/loads/
cd ./loads
$UDO make build || true
$UDO ./bin/pip install "psutil<1.1"
$UDO make build
cd ../

$UDO mkdir ./python-egg-cache
chmod 700 ./python-egg-cache
