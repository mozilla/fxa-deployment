#!/bin/sh

cd /home/app

cat >> circus.ini << EOF

[watcher:loads-broker]
working_dir=/home/app/loads
cmd=./bin/loads-broker --frontend tcp://0.0.0.0:7780 --heartbeat tcp://0.0.0.0:7778 --register tcp://0.0.0.0:7779 --backend tcp://0.0.0.0:7777 --publisher tcp://0.0.0.0:7776 --receiver tcp://0.0.0.0:7781
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

# Try to get the broker process to start up cleanly before the slave.
priority = 10
warmup_delay = 5

[env:loads-broker]
PYTHON_EGG_CACHE = /home/app/python-egg-cache

EOF
