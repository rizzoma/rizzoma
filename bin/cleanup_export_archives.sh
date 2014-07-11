#!/bin/sh
# Cleanup archives that are too old and no more needed.

if [ -z "$1" -o ! -d "$1" ]; then
    echo "Error: archive directory path required"
    echo "Usage: $0 archive_path"
    exit 1
fi
ARCHIVE_PATH=$1

echo "Removing outdated archives"
find $ARCHIVE_PATH -mtime +7 -iname "export-*.zip" -type f -print -delete
echo "Removing empty directories"
find $ARCHIVE_PATH -mindepth 1 -type d -empty -print -delete
echo "Done"
