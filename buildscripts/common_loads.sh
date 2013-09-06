#!/bin/sh

set -e

YUM="yum --assumeyes --enablerepo=epel"
UDO="sudo -u app"

$YUM install nodejs npm gmp gmp-devel libevent-devel
sudo python-pip install virtualenv

# Install loads and loads.js from github master.

cd /home/app
$UDO git clone https://github.com/mozilla-services/loads/
cd ./loads
$UDO make build || true
$UDO ./bin/pip install "psutil<1.1"
$UDO make build
cd ../

$UDO git clone https://github.com/mozilla-services/loads.js
cd ./loads.js/loads.js
$UDO npm install
cd ../../

