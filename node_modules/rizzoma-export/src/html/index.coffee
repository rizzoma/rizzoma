swig = require('swig')

template = swig.compileFile("#{__dirname}/template.html")

exports.toHtml = (markup, params) ->
    parent = "#{__dirname}/../embedded_html/template.html"
    params.offset = -params.offset / 60
    return template.render(
        template: parent
        topic: markup
        params: params
        exportId: (''+Math.random()).substring(2)
    )
