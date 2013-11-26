#!/bin/sh
#
# Single-box heka collector and log-analyzer thing.

set -e

YUM="yum --assumeyes --enablerepo=epel"
UDO="sudo -u app"

cd /home/app


# Install ElasticSearch.

wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.7.tar.gz
tar -zxvf elasticsearch-0.90.7.tar.gz
chown -R app:app elasticsearch-0.90.7
rm -f elasticsearch-0.90.7.tar.gz
mkdir -p /opt
mv ./elasticsearch-0.90.7 /opt/elasticsearch

cat >> /home/app/circus.ini << EOF
[watcher:elasticsearch]
working_dir=/opt/elasticsearch
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
JAVA_HOME=/usr

EOF

mkdir -p /var/data/elasticsearch
chown -R app:app /var/data/elasticsearch

cat >> /opt/elasticsearch/config/elasticsearch.yml << EOF
path.data: /var/data/elasticsearch/data
path.work: /var/data/elasticsearch/work
bootstrap.mlockall: true
indices.memory.index_buffer_size: 50%
index.store.compress.stored: true
EOF


# Install Kibana with a custom dashboard.

KIBANAURL=https://download.elasticsearch.org/kibana/kibana/kibana-3.0.0milestone4.tar.gz
KIBANAFILE=`basename $KIBANAURL`
mkdir -p /opt
cd /opt
wget $KIBANAURL
tar -zxvf $KIBANAFILE
rm -f $KIBANAFILE
mv `basename $KIBANAFILE .tar.gz` kibana
# A big JSON blob defining the custom dashboard.
# This would be much better managed as a separate file in e.g. puppet...
cat >> /opt/kibana/app/dashboards/weblogs.json << EOF
{"index": {"default": "_all", "pattern": "[alllogs-]YYYY-MM-DD", "interval": "none"}, "style": "light", "rows": [{"notice": false, "panels": [{"span": 7, "remember": 10, "title": "query", "editable": true, "label": "Search", "pinned": true, "error": false, "query": "*", "type": "query", "history": ["*"]}, {"status": "Stable", "span": 3, "timespan": "5m", "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"], "filter_id": 0, "title": "Time Picker", "editable": true, "refresh": {"enable": true, "min": 3, "interval": 10}, "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"], "timeformat": "", "mode": "relative", "error": "", "timefield": "Timestamp", "now": true, "type": "timepicker"}], "collapse": false, "title": "Options", "editable": true, "height": "50px", "collapsable": true}, {"notice": false, "panels": [{"editable": true, "type": "filtering", "span": 3, "group": ["default"], "error": false}], "collapse": true, "title": "Filters", "editable": true, "height": "50px", "collapsable": true}, {"notice": false, "panels": [{"show_query": true, "bars": true, "interval": "1s", "zoomlinks": true, "annotate": {"sort": ["_score", "desc"], "query": "*", "enable": false, "field": "_type", "size": 20}, "intervals": ["auto", "1s", "1m", "5m", "10m", "30m", "1h", "3h", "12h", "1d", "1w", "1y"], "timezone": "browser", "spyable": true, "linewidth": 3, "fill": 0, "scale": 1, "span": 10, "tooltip": {"query_as_alias": true, "value_type": "cumulative"}, "stack": true, "derivative": false, "percentage": false, "auto_int": true, "type": "histogram", "value_field": null, "x-axis": true, "pointradius": 5, "editable": true, "zerofill": true, "grid": {"max": null, "min": 0}, "legend": true, "legend_counts": true, "time_field": "Timestamp", "y-axis": true, "lines": false, "points": false, "mode": "count", "queries": {"mode": "all", "ids": [0, 1, 2]}, "y_as_bytes": true, "resolution": 100, "options": true, "interactive": true}], "collapse": false, "title": "Graph", "editable": true, "height": "250px", "collapsable": true}, {"notice": false, "panels": [{"status": "Stable", "header": true, "trimFactor": 300, "spyable": true, "field_list": true, "size": 30, "all_fields": false, "style": {"font-size": "9pt"}, "span": 12, "pages": 10, "type": "table", "sort": ["Timestamp", "desc"], "queries": {"mode": "all", "ids": [0, 1, 2]}, "editable": true, "offset": 0, "group": ["default"], "overflow": "min-height", "normTimes": true, "sortable": true, "fields": ["Timestamp", "Method", "Url", "Status", "RequestTime", "Hostname"], "paging": true, "error": false, "highlight": []}], "collapse": false, "title": "Events", "editable": true, "height": "650px", "collapsable": true}], "title": "PiCL Web Logs", "failover": false, "editable": true, "refresh": "10s", "loader": {"load_gist": true, "hide": false, "save_temp": true, "load_elasticsearch_size": 20, "load_local": true, "save_temp_ttl": "30d", "load_elasticsearch": true, "save_local": true, "save_temp_ttl_enable": true, "save_elasticsearch": true, "save_gist": false, "save_default": true}, "pulldowns": [{"notice": false, "enable": true, "collapse": false, "remember": 10, "pinned": true, "query": "*", "type": "query", "history": []}, {"notice": true, "enable": true, "type": "filtering", "collapse": false}], "nav": [{"status": "Stable", "notice": false, "enable": true, "collapse": false, "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"], "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"], "timefield": "@timestamp", "now": true, "type": "timepicker"}], "services": {"filter": {"list": {"0": {"from": "now-5m", "to": "now", "field": "Timestamp", "alias": "", "mandate": "must", "active": true, "type": "time", "id": 0}}, "ids": [0], "idQueue": [1, 2]}, "query": {"list": {"1": {"enable": true, "pin": false, "color": "#FF9900", "alias": "", "query": "Status:4* AND -Status:499", "type": "lucene", "id": 1}, "0": {"enable": true, "pin": false, "color": "#00FF00", "alias": "", "query": "Status:2*", "type": "lucene", "id": 0}, "2": {"enable": true, "pin": false, "color": "#FF0000", "alias": "", "query": "Status:5* OR Status:499", "type": "lucene", "id": 2}}, "ids": [0, 1, 2], "idQueue": [3, 4]}}, "panel_hints": true}
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
decoder = "aggregator-parser"

[aggregator-parser]
type = "ProtobufDecoder"

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
            alias /opt/kibana;
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


