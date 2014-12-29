#!/bin/bash
# Indefinitely runs run-messages-digest-notificator
cd $(dirname $0)/../

PREV_APP_PID=""
while [ 1 ]; do
    date
    echo "PREV_APP_PID: $PREV_APP_PID"
    APP_PID=`ps -ax -o pid,user,command | grep "/app.js ---sockapi$"`
    echo "APP_PID: $APP_PID";
    if [ -n "$APP_PID" ]; then
        if [ -z "$PREV_APP_PID" -o "$APP_PID" == "$PREV_APP_PID" ]; then
            echo "running notificator"
            node_modules/.bin/cake run-plugin-autosender 2>&1
        fi
        echo "saving new APP_PID"
        PREV_APP_PID="$APP_PID"
    fi
    sleep 300
done
