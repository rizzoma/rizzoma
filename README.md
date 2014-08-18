Rizzoma Collaboration Platform
==============================

Rizzoma is a powerful web-application for realtime collaboration. It was created with Google Wave principles in mind and features tree-structured discussions, gadget-form extensions and multimedia support. Rizzoma is an ultimate solution for team communication which can be used as knowledge-management and discussion platform at the same time. Watch short [video](http://youtu.be/77RYX1uDy_Q) or see it online - [Rizzoma.com](https://rizzoma.com/).

## Just want to get hacking in a virtual machine?
Don't directly clone this repo, but instead get the [Rizzoma Vagrant Skeleton](https://github.com/JonTheNiceGuy/rizzoma_skeleton), follow the steps and get hacking! :)

Want to know how to do it properly on your local machine - follow the steps below!

## Build and run

**Install requirements:**

Node.js 0.10, CouchDB, RabbitMQ, SphinxSearch, Redis (optional), ImageMagick (optional)

On Debian/Ubuntu:
```
sudo apt-add-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install nodejs couchdb rabbitmq-server sphinxsearch redis-server imagemagick libicu-dev
```

**Build:**
- `git clone` and cd to the project root
- `cp src/server/settings_local.coffee.template src/server/settings_local.coffee`
- `node_modules/.bin/cake build-server build-client`
- configure SphinxSearch (optional, TBD)

**Run:**

- `./app.js`
- Open http://localhost:8000/

## Learn internals

Rizzoma architecture described in details in [this topic](https://rizzoma.com/topic/02d87acb18a7d453cbd4cd712b053185/)

In short:
- Operational Transformation (via ShareJS library + our custom types for rich text) for topic state synchronization, concurrent text editing and a bit of offline
- Hard research work for multi-cursor concurrent realtime multi-language WYSIWYG editor with embedded non-editable elements that works in Chrome, Firefox, IE, Safari, Opera, Android and iOS browsers
- CoffeeScript, Browserify for client
- Node.js, CoffeeScript, RabbitMQ, Express, Swig templates for backend
- SockJS (WebSocket) and REST APIs for client-server
- CouchDB, Redis, S3 for data storage
- SphinxSearch for topics/mentions/tasks list and full text search
- Shindig for embedding OpenSocial gadgets
- Google and Facebook oAuth and contacts, email notifications and reply by email, Android application, Hangouts, Google Calendar, Google Drive, Chrome extensions

Other topics: [REST API](https://rizzoma.com/topic/4796b8d26f1258bf15da0a37ee82155f/), [Developing gadgets with OpenSocial](https://rizzoma.com/topic/ec233aca0354f039c71c3e38bb5a3c69/), [Topic export (structure and converters)](https://rizzoma.com/topic/b0d6f7c66f7c784185a7e6f52f8ebb4c/)

## Make changes

**Server side entry points:**
- src/server,
- src/server/app_roles/web_wave.coffee, src/server/templates/wave*.html - web (views and templates),
- src/server/common/root_router.coffee - API module routing.

For most changes to apply just restart `./app.js`.

**Client entry points:**
- src/client, src/static

For .coffee files changes to apply run `node_modules/.bin/cake build-client`, for .css changes - just press F5.

## Help Rizzoma

- Contribute code. Bug fixes, new features, documentation and translations are welcome. Please make one feature or bug fix per pull request. Do not hesitate to ask questions.
- Spread a word, [like](https://www.facebook.com/rizzomacom), star the repo ;)
- Sponsor feature development or just upgrade your Rizzoma plan to support the project.

## Who is behind Rizzoma and license

Rizzoma Project was created and is developed by the [Tekliner](http://tekliner.com/) team with great help from the community.
Rizzoma.com service is provided and supported by Tekliner. Write us a line - support@rizzoma.com

```
Copyright 2011-2014 Tekliner, http://tekliner.com/
Copyright 2011-2014 Rizzoma Project, https://rizzoma.com/

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this project files except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
