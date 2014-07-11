swig = require('swig')

template = swig.compileFile("#{__dirname}/template.html")

exports.toEmbeddedHtml = (markup, params) ->
    return template.render(
        topic: markup
        params: params
        exportId: (''+Math.random()).substring(2)
    )
