#!/bin/bash
if [[ "$@" == *"/bin/sh -c"* ]]; then
    trap 'consul leave' TERM INT
    if [ -z "$CONSULDATA" ]; then export CONSULDATA="/tmp/consul-data";fi
    if [ -z "$CONSULDIR" ]; then export CONSULDIR="/consul";fi
    if [ "$(ls -A $CONSULDIR)" ]; then
        consul agent -data-dir=$CONSULDATA -config-dir=$CONSULDIR $CONSULOPTS &
    fi
    $@ &
    PID=$!
    wait $PID
    trap - TERM INT
    wait $PID
else
    $@
fi