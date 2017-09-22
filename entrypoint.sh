#!/bin/bash


if [[ "$@" == *"/bin/sh -c"* ]]; then
    trap ' kill -TERM $PID' TERM INT
    if [ -z "$CONSULDATA" ]; then export CONSULDATA="/tmp/consul-data";fi
    if [ -z "$CONSULDIR" ]; then export CONSULDIR="/consul";fi
    if [ "$(ls -A $CONSULDIR)" ]; then
        consul agent -data-dir=$CONSULDATA -config-dir=$CONSULDIR $CONSULOPTS &
        CONSUL_PID=$!
        CONSUL_LEAVE='consul leave'
    fi
    CMD=$(echo -e $@ | sed -e 's/\/bin\/sh -c //')
    $CMD &
    PID=$!
    wait $PID
    trap - TERM INT
    wait $PID
    $CONSUL_LEAVE
    wait $CONSUL_PID
else
    $@
fi