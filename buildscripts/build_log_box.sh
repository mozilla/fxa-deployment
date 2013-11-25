#!/bin/sh
#
# Single-box heka collector and log-analyzer thing.

set -e

YUM="yum --assumeyes --enablerepo=epel"
UDO="sudo -u app"

cd /home/app


# Install ElasticSearch.

wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.3.tar.gz
tar -zxvf elasticsearch-0.90.3.tar.gz
chown -R app:app elasticsearch-0.90.3
rm -f elasticsearch-0.90.3.tar.gz
mkdir -p /opt
mv ./elasticsearch-0.90.3 /opt

cat >> /home/app/circus.ini << EOF
[watcher:elasticsearch]
working_dir=/opt/elasticsearch-0.90.3
cmd=bin/elasticsearch -f
numprocesses=1 
stdout_stream.class = FileStream
stdout_stream.filename = /home/app/elasticsearch.stdout.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = /home/app/elasticsearch.stderr.log
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3

[env:elasticsearch]
ES_HEAP_SIZE = 1g

EOF

mkdir -p /var/data/elasticsearch
chown -R app:app /var/data/elasticsearch

cat >> /opt/elasticsearch-0.90.3/config/elasticsearch.yml << EOF
path.data: /var/data/elasticsearch/data
path.work: /var/data/elasticsearch/work
bootstrap.mlockall: true
indices.memory.index_buffer_size: 50%
index.store.compress.stored: true
EOF


# Install Kibana with a custom dashboard.

cd /home/app
wget https://github.com/elasticsearch/kibana/archive/master.tar.gz
mv master.tar.gz kibana-master.tar.gz
mkdir -p /opt
cd /opt
tar -zxvf /home/app/kibana-master.tar.gz
rm /home/app/kibana-master.tar.gz
# A big JSON blob defining the custom dashboard.
# This would be much better managed as a separate file in e.g. puppet...
cat >> /opt/kibana-master/src/app/dashboards/weblogs.json << EOF
{"index": {"default": "_all", "pattern": "[alllogs-]YYYY-MM-DD", "interval": "none"}, "style": "light", "rows": [{"panels": [{"span": 7, "remember": 10, "title": "query", "editable": true, "label": "Search", "pinned": true, "error": false, "query": "*", "type": "query", "history": ["*"]}, {"status": "Stable", "error": "", "span": 3, "timespan": "5m", "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"], "title": "Time Picker", "editable": true, "refresh": {"enable": true, "interval": 10, "min": 3}, "timefield": "Timestamp", "mode": "relative", "filter_id": 0, "timeformat": "", "type": "timepicker"}], "collapse": false, "title": "Options", "editable": true, "height": "50px", "collapsable": true}, {"panels": [{"span": 3, "error": false, "editable": true, "group": ["default"], "type": "filtering"}], "collapse": true, "title": "Filters", "editable": true, "height": "50px", "collapsable": true}, {"panels": [{"bars": true, "interval": "1s", "zoomlinks": true, "timezone": "browser", "spyable": true, "linewidth": 3, "fill": 0, "span": 10, "tooltip": {"value_type": "cumulative", "query_as_alias": false}, "stack": true, "percentage": false, "auto_int": true, "type": "histogram", "value_field": null, "x-axis": true, "editable": true, "legend": true, "time_field": "Timestamp", "y-axis": true, "lines": false, "points": false, "mode": "count", "queries": {"mode": "all", "ids": [1, 0, 2]}, "resolution": 100, "interactive": true}], "collapse": false, "title": "Graph", "editable": true, "height": "250px", "collapsable": true}, {"panels": [{"sort": ["Timestamp", "desc"], "header": true, "trimFactor": 300, "spyable": true, "field_list": true, "size": 30, "style": {"font-size": "9pt"}, "span": 12, "pages": 10, "type": "table", "status": "Stable", "error": false, "editable": true, "offset": 0, "group": ["default"], "overflow": "min-height", "normTimes": true, "sortable": true, "fields": ["Timestamp", "Method", "Url", "Status", "RequestTime", "Hostname"], "paging": true, "queries": {"mode": "all", "ids": [1, 0, 2]}, "highlight": []}], "collapse": false, "title": "Events", "editable": true, "height": "650px", "collapsable": true}], "title": "PiCL Web Logs", "failover": false, "editable": true, "loader": {"load_gist": true, "hide": false, "save_temp": true, "load_elasticsearch_size": 20, "load_local": true, "save_temp_ttl": "30d", "load_elasticsearch": true, "save_local": true, "save_elasticsearch": true, "save_temp_ttl_enable": true, "save_gist": false, "save_default": true}, "services": {"filter": {"list": {"0": {"from": "2013-09-13T01:03:11.871Z", "field": "Timestamp", "to": "2013-09-13T01:08:11.871Z", "alias": "", "mandate": "must", "active": true, "type": "time", "id": 0}}, "ids": [0], "idQueue": [1, 2]}, "query": {"list": {"1": {"pin": false, "color": "#FF9900", "alias": "", "query": "Status:4* AND -Status:499", "type": "lucene", "id": 1}, "0": {"pin": false, "color": "#00FF00", "alias": "", "query": "Status:2*", "type": "lucene", "id": 0}, "2": {"pin": false, "color": "#FF0000", "alias": "", "query": "Status:5* OR Status:499", "type": "lucene", "id": 2}}, "ids": [0, 1, 2], "idQueue": [3, 4]}}}
EOF

# Install RabbitMQ for receving logs from other boxes.

$YUM install rabbitmq-server

cat > /etc/rabbitmq/rabbitmq.config << EOF
[
 {rabbit, [
   {default_user, <<"heka">>},
   {default_pass, <<"{'Ref':'AMQPPassword'}">>}
 ]}
].
EOF

service rabbitmq-server start
chkconfig rabbitmq-server on


# Configure heka to receive logs from all the other boxes via AMQP.
# Nginx logs go into kibana.
# Everything else just gets dumped to the debug log file.
# XXX TODO: security, signing, blah blah blah.

cd /home/app

cat >> /home/app/hekad/hekad.toml << EOF
[aggregator-input]
type = "AMQPInput"
url = "amqp://heka:{"Ref":"AMQPPassword"}@localhost:5672/"
exchange = "heka"
exchangeType = "fanout"

[ElasticSearchOutput]
message_matcher = "Type == 'logfile'"
index = "alllogs-%{2006-01-02}"
esindexfromtimestamp = true
flush_interval = 500
flush_count = 50
EOF


# Configure nginx to serve kibana.

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
    sendfile on;
    server {
        listen       80 default;
        location /kibana {
            alias /opt/kibana-master/src;
            autoindex on;
        }
        location / {
            alias /home/app/www/;
            autoindex on;
        }
    }
}
EOF

cd /home/app
$UDO mkdir www
$UDO chmod +x .
$UDO cat > www/index.html << EOF
<html>
<body>
<a href="/kibana/index.html#/dashboard/file/weblogs.json">Kibana Dashboard</a>
</body>
<html>
EOF

/sbin/chkconfig nginx on
/sbin/service nginx start

