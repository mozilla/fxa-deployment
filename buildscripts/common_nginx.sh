#!/bin/sh
#
# Build nginx proxy support into a box.
#
# This script sets up nginx as a fronting proxy to whatever is running
# on localhost port 8000.  It also adds CORS support and some log-slurping.

set -e

# Setup nginx as proxy for local webserver process.

YUM="yum --assumeyes --enablerepo=epel"

$YUM install nginx

cat << EOF > /etc/nginx/nginx.conf
user  nginx;
worker_processes  1;
events {
    worker_connections  20480;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    log_format xff '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                   '\$status \$body_bytes_sent "\$http_referer" '
                   '"\$http_user_agent" XFF="\$http_x_forwarded_for" '
                   'TIME=\$request_time ';
    access_log /var/log/nginx/access.log xff;
    server {
        listen       80 default;
        location / {
            if (\$request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Allow-Credentials' 'true';
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Access-Control-Allow-Headers' 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type';
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Credentials' 'true';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Access-Control-Allow-Headers' 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type';
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header Host \$http_host;
            proxy_redirect off;
            proxy_pass http://localhost:8000;
        }
    }
}
EOF

/sbin/chkconfig nginx on
/sbin/service nginx start


# Slurp the nginx access log into heka.
# We need to tweak some permissions here to make them readable.

chmod +r /var/log/nginx
chmod +x /var/log/nginx
chmod +r /var/log/nginx/access.log

cat >> /home/app/hekad/hekad.toml << EOF
[nginx-access-log]
type = "LogfileInput"
logfile = "/var/log/nginx/access.log"
decoder = "nginx-log-decoder"

[nginx-log-decoder]
type = "PayloadRegexDecoder"
timestamp_layout = "02/Jan/2006:15:04:05 -0700"
match_regex = '^(?P<RemoteIP>\S+) \S+ \S+ \[(?P<Timestamp>[^\]]+)\] "(?P<Method>[A-Z\-]+) (?P<Url>[^\s]+)[^"]*" (?P<StatusCode>\d+) (?P<RequestSize>\d+) "(?P<Referer>[^"]*)" "(?P<Browser>[^"]*)" XFF="(?P<XFF>[^"]+)" TIME=(?P<Time>\S+)'

[nginx-log-decoder.message_fields]
Type = "logfile"
Logger = "nginx"
Url|uri = "%Url%"
Method = "%Method%"
Status = "%StatusCode%"
RequestSize|B = "%RequestSize%"
Referer = "%Referer%"
Browser = "%Browser%"
RequestTime = "%Time%"
XForwardedFor = "%XFF%"

EOF
