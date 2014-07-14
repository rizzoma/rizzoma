#!/bin/sh

# Install requirements
sudo add-apt-repository --yes ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get --yes install nodejs couchdb rabbitmq-server sphinxsearch redis-server imagemagick libicu-dev

# Configure rizzoma (maybe unnecessary since also happens in cake init?)
cp src/server/settings_local.coffee.template src/server/settings_local.coffee

# Configure Sphinxsearch
sudo sed -i "s/START=no/START=yes/" /etc/default/sphinxsearch
./bin/edit_sudoers_for_sphinxsearch.sh
# copy sphinx conf and insert actual rizzoma directory
DIRECTORY=`pwd`
sudo cp ./etc/sphinxsearch/sphinx.conf /etc/sphinxsearch/sphinx.conf
sudo sed -i "s#/path_to_project#${DIRECTORY}#" /etc/sphinxsearch/sphinx.conf
# stop daily rotating
sudo cp ./etc/cron.d/sphinxsearch /etc/cron.d/sphinxsearch 

# Build rizzoma and init sphinxsearch
node_modules/.bin/cake init
