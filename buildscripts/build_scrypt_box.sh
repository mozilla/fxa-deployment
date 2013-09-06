#!/bin/sh
#
# Build a webhead node for scrypt-helper.
#
# This script builds a custom machine setup for running the scrypt-helper
# python application.

set -e

UDO="sudo -u app"

YUM="yum --assumeyes --enablerepo=epel"

# Grab and build the latest master of scrypt-helper.

$YUM install openssl-devel python-devel gcc gcc-c++
python-pip install virtualenv

cd /home/app
$UDO git clone https://github.com/mozilla/scrypt-helper.git
cd ./scrypt-helper

$UDO virtualenv --no-site-packages ./local
$UDO ./local/bin/pip install .
$UDO ./local/bin/pip install gunicorn


# Write a circus config file to run the app with gunicorn.
# We run with a very low socket backlog so that requests will fail
# quickly if the server gets overloaded.

cd ../
cat >> circus.ini << EOF
[watcher:scrypt-helper]
working_dir=/home/app/scrypt-helper
cmd=local/bin/gunicorn --workers=5 --error-logfile=- --access-logfile=- scrypt_helper.run
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = /home/app/scrypt-helper/circus.stdout.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = /home/app/scrypt-helper/circus.stderr.log
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3
EOF


# XXX TODO: any useful logs we can slurp into heka?
