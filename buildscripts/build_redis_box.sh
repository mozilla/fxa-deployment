#!/bin/sh
#
# Build a stand-alone redis storage node.

set -e

UDO="sudo -u app"

YUM="yum --assumeyes --enablerepo=epel"

cd /home/app

# We need a newer version of redis than is available in the repo.
# Build it from source.

REDISURL=http://download.redis.io/releases/redis-2.8.2.tar.gz
REDISFILE=`basename $REDISURL`
REDISDIR=`basename $REDISURL .tar.gz`
REDISSHA1=3be038b9d095ce3dece7918aae810d14fe770400

wget $REDISURL
if [ `sha1sum $REDISFILE | cut -d ' ' -f 1` != $REDISSHA1] ; then
  echo 'sha1sum mismatch for redis source tarball'
  exit 1
fi

tar -xzvf $REDISFILE
rm -rf $REDISFILE
cd $REDISDIR
make
perl -pi -e 's/timeout 0/timeout 30/g' ./redis.conf
perl -pi -e 's/# requirepass foobared/requirepass {"Ref": "RedisPassword"}/g' ./redis.conf
perl -pi -e 's/# maxclients 128/maxclients 128/g' ./redis.conf
perl -pi -e 's/# maxmemory <bytes>/maxmemory 67108864/g' ./redis.conf
cd ../
mv $REDISDIR ./redis
chown -R app:app ./redis


# Use circus to start redis on boot.
# The source disribution doesn't come with a compatible init-script.

cat >> circus.ini << EOF

[watcher:redis]
working_dir=/home/app/redis
cmd=/home/app/redis/src/redis-server /home/app/redis/redis.conf
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = /home/app/redis/circus.stdout.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = /home/app/redis/circus.stderr.log
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3

EOF

