#!/bin/sh
#
# Build a webhead node for tokenserver

set -e

UDO="sudo -u app"

YUM="yum --assumeyes --enablerepo=epel"

# Install and configure local MySQL server.

$YUM install mysql mysql-server

/sbin/chkconfig mysqld on
/sbin/service mysqld start

echo "CREATE USER 'token'@'localhost' IDENTIFIED BY 'tokenizationing';" | mysql -u root
echo "CREATE DATABASE token;" | mysql -u root
echo "GRANT ALL ON token.* TO 'token';" | mysql -u root


# Grab and build the latest master of tokenserver.

$YUM install openssl-devel python-devel gcc gcc-c++
python-pip install virtualenv

cd /home/app
$UDO git clone https://github.com/mozilla-services/tokenserver
cd tokenserver
make build TIMEOUT=600
./bin/pip install gunicorn


# Write the configuration files.

cat > ./etc/production.ini << EOF
[global]
logger_name = tokenserver
debug = false

[server:main]
use = egg:Paste#http
host = 0.0.0.0
port = 8000

[pipeline:main]
pipeline = catcherrorfilter
           tokenserverapp

[filter:catcherrorfilter]
paste.filter_app_factory = mozsvc.middlewares:make_err_mdw

[app:tokenserverapp]
use = egg:tokenserver
mako.directories = cornice:templates
pyramid.reload_templates = true
pyramid.debug = false

[loggers]
keys = root, tokenserver, mozsvc, wimms

[handlers]
keys = console
[formatters]
keys = generic

[logger_root]
level = INFO
handlers = console

[logger_tokenserver]
level = INFO
handlers = console
qualname = tokenserver

[logger_mozsvc]
level = INFO
handlers = console
qualname = mozsvc

[logger_wimms]
level = INFO
handlers = console
qualname = wimms

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = INFO
formatter = generic

[formatter_generic]
format = %(asctime)s %(levelname)-5.5s [%(name)s][%(threadName)s] %(message)s

[tokenserver]
applications = sync-1.5
secrets_file = ./etc/secrets
backend = tokenserver.assignment.sqlnode.SQLNodeAssignment
sqluri = pymysql://token:tokenizationing@localhost/token
create_tables = true
pool_size = 5
token_duration = 300

[browserid]
backend = tokenserver.verifiers.RemoteVerifier
audiences = https://token.{"Ref":"DNSPrefix"}.lcip.org

EOF
chown app:app ./etc/production.ini


# The secrets file needs to list all the available nodes and their
# secrets.  How to best manage this is an open question.

cat > ./etc/secrets << EOF
https://sync1.{"Ref":"DNSPrefix"}.lcip.org,123456:SECRETKEYOHSECRETKEY
https://sync2.{"Ref":"DNSPrefix"}.lcip.org,123457:SECRETLYMYSECRETKEY
EOF
chown app:app ./etc/secrets


# Import the python app, to let it create its database tables.

TOKEN_INI=/home/app/tokenserver/etc/production.ini ./bin/python -c "import tokenserver.run"

# Add db records for the service.
echo "INSERT INTO token.services VALUES (1, 'sync-1.5', '{node}/1.5/{uid}');" | mysql -u root


# Add db records for the known nodes in this cluster.
# Ideally they would register themselves into the db at bootup.

echo "INSERT INTO token.nodes VALUES (1, 1, 'https://sync1.{"Ref":"DNSPrefix"}.lcip.org', 10000, 0, 10000, 0, 0);" | mysql -u root
echo "INSERT INTO token.nodes VALUES (2, 1, 'https://sync2.{"Ref":"DNSPrefix"}.lcip.org', 10000, 0, 10000, 0, 0);" | mysql -u root


# Write a circus config file to run the app with gunicorn

cd ../
cat >> circus.ini << EOF
[watcher:tokenserver]
working_dir=/home/app/tokenserver
cmd=bin/gunicorn_paster -k gevent -w 4 ./etc/production.ini
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = tokenserver.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = tokenserver.err
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3
EOF

