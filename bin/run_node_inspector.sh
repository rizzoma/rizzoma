#!/bin/sh
# Script starts node-inspector if it is not running

cd $(dirname $0)/../
pgrep -f "node-inspector$" && echo "node-inspector already running" || (echo "Starting node-inspector..." && node_modules/.bin/node-inspector)
