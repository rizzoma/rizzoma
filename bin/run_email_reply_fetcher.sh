#!/bin/bash
# run-email-reply-fetcher
cd $(dirname $0)/../

date
node_modules/.bin/cake run-email-reply-fetcher 2>&1
