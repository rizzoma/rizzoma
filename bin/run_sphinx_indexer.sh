#!/bin/bash

# Запускает наполнение данными одного индекса

if [ -z "$INDEX_PREFIX" ]; then
    echo "Environment variable INDEX_PREFIX must be set"
    exit 1
fi

if [ -z "$1" ]; then
    echo "parameter INDEX_NUMBER must be set"
    exit 1
fi

CONF=""
if [ -n "$SPHINX_CONF" ]; then
    CONF="--config ${SPHINX_CONF} "
fi

sudo -u sphinxsearch indexer ${CONF}--rotate ${INDEX_PREFIX}_${1}_index



