#!/bin/bash
# Script creates directories and runs first indexing

if [ -z $INDEX_PREFIX ]; then
    echo "Environment variable INDEX_PREFIX must be set"
    exit 1
fi

if [ -e "/var/lib/sphinxsearch/data/${INDEX_PREFIX}_0" ] ; then
    echo "Error: indexes already exists (/var/lib/sphinxsearch/data/${INDEX_PREFIX}_{0,1,2})."
    echo "To continue remove them with 'INDEX_PREFIX=${INDEX_PREFIX} bin/remove_sphinx_indexes.sh'. Exiting..."
    exit 1
fi

sudo service sphinxsearch stop
sleep 5

cd $(dirname $0)/../

echo "init:1/6 Creating dirs for indexes"

for i in $(seq 0 2); do
    sudo mkdir -p /var/lib/sphinxsearch/data/${INDEX_PREFIX}_${i}
done

sudo mkdir -p /var/log/sphinxsearch

echo "init:2/6 Changing directories owner"

sudo chown -R sphinxsearch /var/log/sphinxsearch /var/lib/sphinxsearch /var/run/sphinxsearch

echo "init:3/6 Creating empty indexes"

for i in $(seq 0 2); do
    sudo -u sphinxsearch INDEX_TYPE=empty indexer --rotate ${INDEX_PREFIX}_${i}_index
done

sudo service sphinxsearch start
sleep 5

sudo service sphinxsearch stop
MERGING_TIMESTAMP=`date +%s`
echo "init:4/6 Generating full index"

sudo rm -r /var/lib/sphinxsearch/full-previous
sudo mv /var/lib/sphinxsearch/{full,full-previous}
./bin/run_full_indexer.sh
sleep 5

echo "init:5/6 Copy full_0 index to working ${INDEX_PREFIX}_0 index"

sudo cp /var/lib/sphinxsearch/{full/full_0/index.*,data/${INDEX_PREFIX}_0/}

echo "init:6/6 Creating state files"
OWNER=$1
if [ -z $OWNER ]; then
OWNER=$USER
fi
echo "Owner is ${OWNER}"

sudo sh -c "echo ${MERGING_TIMESTAMP} > /var/lib/sphinxsearch/data/${INDEX_PREFIX}_1/merge_state.txt"
sudo chown www-data:${OWNER} /var/lib/sphinxsearch/data/${INDEX_PREFIX}_1/merge_state.txt
sudo chmod 0664 /var/lib/sphinxsearch/data/${INDEX_PREFIX}_1/merge_state.txt

sudo sh -c "echo ${MERGING_TIMESTAMP} > /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/merge_state.txt"
sudo chown www-data:${OWNER} /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/merge_state.txt
sudo chmod 0664 /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/merge_state.txt

sudo sh -c "echo ${MERGING_TIMESTAMP} > /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/backup_state.txt"
sudo chown www-data:${OWNER} /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/backup_state.txt
sudo chmod 0664 /var/lib/sphinxsearch/data/${INDEX_PREFIX}_0/backup_state.txt

sleep 5
sudo service sphinxsearch start