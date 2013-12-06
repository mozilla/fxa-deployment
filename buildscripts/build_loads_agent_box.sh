#!/bin/sh

cd /home/app

UDO="sudo -u app"

# Run the loads-agent command via circus.

cat >> circus.ini << EOF

[watcher:loads-agent]
working_dir=/home/app/loads
cmd=./bin/loads-agent --broker tcp://broker.loads.lcip.org:7780
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = /home/app/loads/circus.stdout.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = FileStream
stderr_stream.filename = /home/app/loads/circus.stderr.log
stderr_stream.refresh_time = 0.5
stderr_stream.max_bytes = 1073741824
stderr_stream.backup_count = 3

[env:loads-agent]
PYTHON_EGG_CACHE = /home/app/python-egg-cache

EOF
