#!/bin/sh
#
# Build support for heka client box.
#
# This script sets up heka to forward all its logs to a special log
# aggregtor box.

set -e

YUM="yum --assumeyes --enablerepo=epel"

# Configure heka to forward logs to the logbox
# XXX TODO: set logging URL at deploy time, rather than baking into AMI.
# XXX TODO: security anyone?

cat >> /home/app/hekad/hekad.toml << EOF

[aggregator-output]
type = "AMQPOutput"
message_matcher = "TRUE"
url = "amqp://heka:{"Ref":"AMQPPassword"}@logs.{"Ref":"DNSPrefix"}.lcip.org:5672/"
exchange = "heka"
exchangeType = "fanout"

EOF
