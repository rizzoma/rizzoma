#!/bin/sh
# Gzip static files for serving with nginx's gzip_static

if [ -z "$1" ] ; then
    echo "Error: lib/ subdirectory name needed."
    echo "Use command: $(basename $0) subdir"
    exit 1
fi

cd $(dirname $0)/../
STATIC_DIR=lib/$1/

if [ ! -d "$STATIC_DIR" ] ; then
    echo "Error: directory $STATIC_DIR does not exists"
    exit 1
fi

echo -n "Compressing files: "
# woff eot не сжимаем потому что они и так сжаты
for f in `find $STATIC_DIR -type f -regextype "posix-extended" -regex ".*\.(css|js|txt|html|xml|ttf|svg)"` ; do
    echo -n "${f##$STATIC_DIR}, "
    f_compressed="$f.gz"

    # compress file
    cat $f | gzip -9 > $f_compressed
    # and set the same modification time
    touch --reference=$f $f_compressed
done
echo "Done"