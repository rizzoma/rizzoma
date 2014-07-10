#!/bin/sh
# Script generates and outputs full search index

cd $(dirname $0)/../
echo '<?xml version="1.0" encoding="utf-8"?>'
echo '<sphinx:docset>'
cat ./bin/search_scheme.xml
./node_modules/.bin/cake generate-full-search-index
echo '</sphinx:docset>'
#node --max-old-space-size=1900 ./node_modules/.bin/cake -i "$1" generate-search-index