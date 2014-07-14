SHELL=/bin/bash
USERNAME = ${USER}

install: install-requirements configure-rizzoma build-rizzoma #configure sphinxsearch build-sphinxsearch

install-requirements:
	sudo add-apt-repository --yes ppa:chris-lea/node.js
	sudo apt-get update
	sudo apt-get --yes install nodejs couchdb rabbitmq-server sphinxsearch redis-server imagemagick libicu-dev

configure-rizzoma:
	cp src/server/settings_local.coffee.template src/server/settings_local.coffee

build-rizzoma:
	./node_modules/.bin/cake build-server build-client

configure-sphinxsearch:
	sudo sed -i "s/START=no/START=yes/" /etc/default/sphinxsearch

change-sudoers-file:
	test -s /etc/sudoers.rizzoma.bkp
	sudo cp /etc/sudoers /etc/sudoers.rizzoma.bkp
	sudo sed -i "s/Defaults	env_reset/Defaults	env_reset\nDefaults	env_keep += \"INDEX_PREFIX INDEX_TYPE\"/" /etc/sudoers
	sudo echo -e "\n${USERNAME}	ALL=(sphinxsearch)NOPASSWD: /usr/bin/indexer * \n"  >> /etc/sudoers
	
