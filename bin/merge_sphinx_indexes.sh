#!/bin/sh

# Merge two indexes: $2 into $1.
# Params: $1 - destination index number, $2 - source index number.

if [ -z "$INDEX_PREFIX" ]; then
    echo "Environment variable INDEX_PREFIX must be set"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Error: 1st parameter INTO_INDEX_NUMBER must be set"
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: 2nd parameter FROM_INDEX_NUMBER must be set"
    exit 1
fi

CONF=""
if [ -n "$SPHINX_CONF" ]; then
    CONF="--config ${SPHINX_CONF}"
fi

# discard kill list only when merging ONE into ZERO, do not when merging TWO into ONE indexes
MERGE_KLISTS=""
if [ "$1" != "0" ]; then
    MERGE_KLISTS="--merge-klists"
fi

sleep 5s
echo "sudo -u sphinxsearch indexer ${CONF} --rotate ${MERGE_KLISTS} --merge ${INDEX_PREFIX}_${1}_index ${INDEX_PREFIX}_${2}_index"
sudo -u sphinxsearch indexer ${CONF} --rotate ${MERGE_KLISTS} --merge ${INDEX_PREFIX}_${1}_index ${INDEX_PREFIX}_${2}_index

echo "sudo -u sphinxsearch INDEX_TYPE=empty indexer ${CONF} --rotate ${INDEX_PREFIX}_${2}_index"
sudo -u sphinxsearch INDEX_TYPE=empty indexer ${CONF} --rotate ${INDEX_PREFIX}_${2}_index
