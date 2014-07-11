#!/bin/sh

cd $(dirname $0)/../

SPHINX_CONF="./lib/etc/sphinxsearch/full-indexing.conf"
if [ ! -f "${SPHINX_CONF}" ] ; then
    ./node_modules/.bin/cake make-full-indexer-sphinx-conf
fi

STATE_FILE="/var/lib/sphinxsearch/full/full-indexing-state.txt"

sudo -u sphinxsearch searchd -c ${SPHINX_CONF} --stop
sleep 3

if [ ! -f "${STATE_FILE}" ] ; then
    echo "init: Creating dirs for indexes"
    for i in $(seq 0 1); do
        sudo mkdir -p /var/lib/sphinxsearch/full/full_${i}
    done

    echo "init: Changing directories owner"
    sudo chown -R sphinxsearch /var/lib/sphinxsearch/full

    echo "init: Creating empty indexes"
    for i in $(seq 0 1); do
        sudo -u sphinxsearch INDEX_TYPE=empty indexer --config ${SPHINX_CONF} --rotate full_${i}_index
    done
fi

sudo -u sphinxsearch searchd -c ${SPHINX_CONF}
sleep 5

echo "run: Generating indexes"
./node_modules/.bin/cake run-full-indexer

sleep 5
sudo -u sphinxsearch searchd -c ${SPHINX_CONF} --stop