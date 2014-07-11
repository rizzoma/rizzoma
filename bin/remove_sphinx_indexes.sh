#!/bin/sh
# Script removes old Sphinx search indexes (if any)

if [ -z $INDEX_PREFIX ]; then
    echo "Environment variable INDEX_PREFIX must be set"
    exit 1
fi

sudo service sphinxsearch stop
sleep 5
for i in $(seq 0 2); do
    sudo rm -rf /var/lib/sphinxsearch/data/${INDEX_PREFIX}_${i}
done

echo "Note: to reindex all messages in db you also should run 'INDEX_PREFIX=${INDEX_PREFIX} bin/init_sphinx_indexer.sh'"
