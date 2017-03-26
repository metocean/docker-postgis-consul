#!/bin/bash
if [[ "$@" == *"/bin/sh -c"* ]]; then
    trap 'consul leave; kill -TERM `cat /var/run/postgresql/9.5-main.pid`' TERM INT
    if [ -z "$CONSULDATA" ]; then export CONSULDATA="/tmp/consul-data";fi
    if [ -z "$CONSULDIR" ]; then export CONSULDIR="/consul";fi
    if [ "$(ls -A $CONSULDIR)" ]; then
        consul agent -data-dir=$CONSULDATA -config-dir=$CONSULDIR $CONSULOPTS &
        CONSUL_PID=$!
        
    fi
    $@ &
    PID=$!
    wait $PID
    trap - TERM INT
    wait $CONSUL_PID
else
    $@
fi