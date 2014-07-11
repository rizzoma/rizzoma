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

# routes
# 1. index page (static file)
app.get "/", serveStatic(__dirname + '/../../../src/pages', 'index.html')

# 2. old index page (built with templates)
#indexTemplate = Conf.getTemplate().compileFile('index.html')
#app.get "/0/", (req, res) ->
#    params =
#        siteAnalytics: Conf.get('siteAnalytics')
#    try
#        res.send indexTemplate.render(params)
#    catch e
#        Conf.getLogger('http').error(e)
#        res.send 500

# 3. static pages
app.get /^\/[^\/]+\.html$/, serveStatic(__dirname + '/../../../src/pages')