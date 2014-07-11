swig = require('swig')
{app} = require('./web_base')
anonymous = require('../user/anonymous')
{BlipSearchController} = require('../blip/search_controller')
{Conf} = require('../conf')

template = swig.compileFile('tag_search.html')

app.get new RegExp("^#{Conf.getTagSearchUrl()}(.+)$"), (req, res) ->
    query = "##{req.params[0]}"
    BlipSearchController.searchPublicBlips anonymous, query, null, (error, result) ->
        return res.send(500) if error
        content = template.render
            query: query
            url: Conf.getWaveUrl()
            topics: result.searchResults
        res.send(content)
