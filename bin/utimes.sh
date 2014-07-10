#!/bin/bash

cd $(dirname $0)/../

SRC_DIR=$1
DST_DIR=$2

if [ -z "$SRC_DIR" -o -z "$DST_DIR" ] ; then
    echo "Error: src and dst directory names needed."
    echo "Use command: $(basename $0) src_dir dst_dir"
    exit 1
fi

if [ ! -d "$SRC_DIR" ] ; then
    echo "Error: directory SRC_DIR does not exists"
    exit 1
fi

if [ ! -d "$DST_DIR" ] ; then
    echo "Error: directory $DST_DIR does not exists"
    exit 1
fi

# проставляет время модифицирования файлма в папке DST_DIR на основании файлов в папке SRC_DIR

for dstf in `find $DST_DIR -type f -regextype "posix-extended" -regex ".*\.(css|js|txt|html|xml|ttf|svg|woff|eot|png|gif|jpg|bmp|http)"` ; do
    srcf="$SRC_DIR${dstf##$DST_DIR}"
    if [ -f "$srcf" ] ; then
        echo "touching '$dstf' with time from '$srcf'"
        # and set the same modification time
        touch --reference=$srcf $dstf
    fi
done
