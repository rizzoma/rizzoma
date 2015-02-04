###
Роль для запуска главной страницы и статики всего проекта
###
Conf = require('../conf').Conf
app = require('./web_base').app

if Conf.get('app')?.dynamicBrowserify
    # Browserify will rebuild client js file on the fly
    opts =
        mount: '/s/js/index.js'
        entry: __dirname + '/../../client_index.coffee'
        watch: true
        cache: true

    browserify = require('browserify')(opts)
    app.get new RegExp('^/s/js/index.js'), browserify

# static
{serveStatic} = require('../utils/express')
app.get /\/s\/page(\/.*)/, serveStatic(__dirname + '/../../../src/pages/s/page')
app.get /\/s(\/.*)/, serveStatic(__dirname + '/../../../lib/static')
# for local file processor/storage
# TODO: get from conf
app.get /\/f(\/.*)/, serveStatic(__dirname + '/../../../data/uploaded-files')

# routes
# 1. index page (static file or fallback - redirect to /topic/)
app.get "/", serveStatic(__dirname + '/../../../src/pages', 'index.html'), (req, res) ->
    # 2.no html found, just make /topic/ redirect
    res.redirect('/topic/')

# 3. static pages
app.get /^\/[^\/]+\.html$/, serveStatic(__dirname + '/../../../src/pages')