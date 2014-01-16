#!/bin/sh
#
# Build a webhead node for syncstorage.

set -e

UDO="sudo -u app"

YUM="yum --assumeyes --enablerepo=epel"


# Install and configure local MySQL server.

$YUM install mysql mysql-server

/sbin/chkconfig mysqld on
/sbin/service mysqld start

echo "CREATE USER 'sync' IDENTIFIED BY 'syncerific';" | mysql -u root
echo "CREATE USER 'sync'@'localhost' IDENTIFIED BY 'syncerific';" | mysql -u root
echo "CREATE DATABASE sync;" | mysql -u root
echo "GRANT ALL ON sync.* TO 'sync';" | mysql -u root


# Grab and build the latest master of tokenserver.

$YUM install openssl-devel python-devel gcc gcc-c++
python-pip install virtualenv

cd /home/app
$UDO git clone https://github.com/mozilla-services/server-syncstorage
cd server-syncstorage
git checkout -t origin/rfk/sync-1.5
make build
./local/bin/pip install gunicorn gevent


# Write the configuration files.

cat > production.ini << EOF
[server:main]
use = egg:Paste#http
host = 0.0.0.0
port = 8000

[app:main]
use = egg:SyncStorage

[storage]
backend = syncstorage.storage.sql.SQLStorage
sqluri = pymysql://sync:syncerific@localhost/sync
standard_collections = false
use_quota = false
pool_size = 2
pool_overflow = 5
pool_recycle = 3600
reset_on_return = true
create_tables = true

[hawkauth]
secret = "SECRETKEYOHSECRETKEY"

[metlog]
backend = mozsvc.metrics.MetlogPlugin
logger = syncstorage
sender_class = metlog.senders.DebugCaptureSender

[cef]
use = true
file = syslog
vendor = mozilla
version = 0
device_version = 1.3
product = weave

EOF
chown app:app ./production.ini


# Write a circus config file to run the app with gunicorn

cd ../
cat >> circus.ini << EOF
[watcher:syncstorage]
working_dir=/home/app/server-syncstorage
cmd=local/bin/gunicorn_paster -k gevent -w 4 production.ini
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = sync.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = sync.err
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3
EOF

