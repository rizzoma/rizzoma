#!/bin/bash

cd $(dirname $0)/../

date | tee -a deploy.log
./node_modules/.bin/cake deploy 2>&1 | tee -a deploy.log
exit ${PIPESTATUS[0]}
