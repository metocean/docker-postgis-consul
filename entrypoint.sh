#!/bin/bash
if [[ -n "$@" ]]; then
    trap 'consul leave' TERM INT
    if [ -z "$CONSULDATA" ]; then export CONSULDATA="/tmp/consul-data";fi
    if [ -z "$CONSULDIR" ]; then export CONSULDIR="/consul";fi
    if [ "$(ls -A $CONSULDIR)" ]; then
        consul agent -data-dir=$CONSULDATA -config-dir=$CONSULDIR &
    fi
    $@ &
    PID=$!
    wait $PID
    trap - TERM INT
    wait $PID
elif [[ -z "$@" || "$@" == "/bin/bash" ]]; then
    /bin/bash
else
    $@
fi