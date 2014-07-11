ModelType = require('./model').ModelType
ParamsField = require('./model').ParamsField
Utf16Util = require('../utils/string').Utf16Util
{MAX_URL_LENGTH} = require('./common')
{ParsedElementProcessor} = require('../../share/parser')

DATA_VARS =
    BLIP_PARAMS: 'rzBlipParams'
    CLIPBOARD: 'rzClipboard'
    PARAMS: 'rzParams'

DATA_ATTRS =
    BLIP_PARAMS: 'data-rz-blip-params'
    CLIPBOARD: 'data-rz-clipboard'
    PARAMS: 'data-rz-params'

module.exports = require('../../share/parser')

class HtmlParser extends module.exports.HtmlParser
    __insertImgOp: (ops, url) ->
        return @_skipped = yes if url.length > MAX_URL_LENGTH
        super(ops, url)

    parse: (args...) ->
        @_skipped = no
        super(args...)

module.exports.HtmlParser = HtmlParser

class HtmlOpParser
    _createIterator: (rootNode) ->
        filter = (node) ->
            if node.dataset
                !!node.dataset[DATA_VARS.PARAMS]?
            else
                !!node.getAttribute(DATA_ATTRS.PARAMS)
        document.createNodeIterator(rootNode, NodeFilter.SHOW_ELEMENT, filter, no)

    parse: (rootNode, offset) ->
        iterator = @_createIterator(rootNode)
        element = null
        ops = []
        while(element = iterator.nextNode())
            if element.dataset
                params = JSON.parse(element.dataset[DATA_VARS.PARAMS])
            else
                params = JSON.parse(element.getAttribute(DATA_ATTRS.PARAMS))
            switch params[ParamsField.TYPE]
                when ModelType.TEXT
                    text = element.textContent
                    text = Utf16Util.traverseString(text)
                    continue if not text or not text.length
                    op = {p: offset, ti: text, params: params}
                    offset += text.length
                when ModelType.BLIP
                    if element.dataset
                        blipParams = JSON.parse(element.dataset[DATA_VARS.BLIP_PARAMS])
                    else
                        blipParams = JSON.parse(element.getAttribute(DATA_ATTRS.BLIP_PARAMS))
                    container = document.createElement('span')
                    while element.firstChild
                        container.appendChild(element.firstChild)
                    blipOps = @parse(container, 0)
                    op = {p: offset, ti: ' ', params: params, blipParams: blipParams, ops: blipOps}
                    offset += 1
                else
                    op = {p: offset, ti: ' ', params: params}
                    offset += 1
            ops.push(op)
        ops


class OpParsedElementProcessor extends ParsedElementProcessor
    ###
    Реализация интерфейса для совершения действий с результатами парсинга для генерации операций
    ###
    createParsedElement: (text, params, offset) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        return {p: offset, ti: text, params: params}

    getParsedElementText: (op) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        return op?.ti

    setParsedElementText: (op, text) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        op.ti = text


module.exports.HtmlOpParser = HtmlOpParser
module.exports.OpParsedElementProcessor = new OpParsedElementProcessor()
module.exports.DATA_VARS = DATA_VARS
module.exports.DATA_ATTRS = DATA_ATTRS
