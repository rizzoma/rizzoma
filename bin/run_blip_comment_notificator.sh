#!/bin/sh
# Indefinitely runs blip comment notificator
cd $(dirname $0)/../

while [ 1 ]; do
    date
    node_modules/.bin/cake run-blip-comment-notificator 2>&1
    sleep 300
done


