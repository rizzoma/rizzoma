escapeHTML = require('../../utils/string').escapeHTML

attachmentTmpl = ->
    div '.attachment-content', ->
        a {href: h(@src), rel: h(@rel)}, ->
            img '.attachment-preview', {src: h(@src), alt: ''}
renderAttachment = window.CoffeeKup.compile(attachmentTmpl)

class Attachment
    constructor: (args...) ->
       @_init(args...)

    _init: (@_rel, url) ->
        @_url = url
        @_createDom()

    _createDom: ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        params =
            src: @_url
            rel: @_rel
        $(@_container).append(renderAttachment params)

    getContainer: ->
        return @_container

exports.Attachment = Attachment
