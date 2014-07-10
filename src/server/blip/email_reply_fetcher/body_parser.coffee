jsdom  = require("jsdom")
{HtmlParser} = require('../../../share/parser')
{TextParser} = require('../../../share/parser')
{ParsedElementProcessor} = require('../../../share/parser')
{EmailReplyParser} = require('../../utils/email_reply_parser')
{strip} = require('../../../share/utils/string')
{Conf} = require('../../conf')

class BlockParsedElementProcessor extends ParsedElementProcessor
    ###
    Реализация интерфейса для совершения действий с результатами парсинга для генерации блоков контента блипа
    ###
    createParsedElement: (text, params, offset) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        return {t: text, params: params}

    getParsedElementText: (op) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        return op?.t

    setParsedElementText: (op, text) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        op.t = text

class BaseEmailBodyParser

    constructor: () ->
        @_logger = Conf.getLogger('email-body-parser')
        @_htmlParser = new HtmlParser(new BlockParsedElementProcessor(), 0)
        @_textParser = new TextParser(new BlockParsedElementProcessor(), 0)
        @_responseCallbacks = {}

    _replaceNotificationHrefs: (text) ->
        pattern = /\/notification\/settings\/\?email=[^&]+&(?:amp;)?hash=\w+/g
        replace = '/notification/settings/?email=xxx&hash=xxx'
        text = text.replace(pattern, replace)
        return text

    getBlipContent: (mail) ->
        return @_parseHtml(mail.html) if mail.html
        return @_parseText(mail.text) if mail.text
        @_logger.error("Mail #{mail.getId()} hasn't any body")
        return ""

    _parseHtml: (html) ->
        html = @_replaceNotificationHrefs(html)
        doc = @_createDomDocument(html)
        doc = @_cutCiteFromDomDocument(doc)
        return @_parseDomDocument(doc.firstChild)

    _createDomDocument: (html) ->
        global.document = jsdom.jsdom().createWindow().document
        span = document.createElement('span')
        span.innerHTML = html
        document.body.appendChild(span)
        return document

    _cutCiteFromDomDocument: (doc) ->
        ###
        Вырезает цитату из письма
        @param doc: HtmlDomDocument
        @returns: HtmlDomDocument
        ###
        throw new Error('Not implemented')

    _isTextBlock: (block) ->
        return block.params.__TYPE == 'TEXT'

    _isBlockToTrim: (block) ->
        ###
        Отрезабельный ли блок
        ###
        return block.params.__TYPE == 'LINE' or @_isTextBlock(block) and /^\s+$/g.test(block.t)

    _rtrimContent: (content) ->
        ###
        Отрезает все справа
        @param content: Array
        ###
        i = content.length - 1
        while i != -1 and @_isBlockToTrim(content[i])
            content.pop()
            i = content.length - 1
        content[i].t = @_rtrimText(content[i].t) if content.length and @_isTextBlock(content[i])
        return content

    _ltrimContent: (content) ->
        ###
        Отрезает все слева
        @param content: Array
        ###
        while content.length and @_isBlockToTrim(content[0])
            content.shift()
        content[0].t = @_ltrimText(content[0].t) if content.length and @_isTextBlock(content[0])
        return content

    _trimContent: (content) ->
        ###
        Отрезает все отовсюду
        @param content: Array
        ###
        return @_ltrimContent(@_rtrimContent(content))

    _parseDomDocument: (doc) ->
        ###
        Парсит HtmlDomDocument в наш формат snapshot
        @param doc: HtmlDomDocument
        @returns: Array
        ###
        content = @_htmlParser.parse(doc)
        return @_trimContent(content)

    _trimText: (text) ->
        return strip(text)

    _rtrimText: (text) ->
        text.replace(/\s+$/g, '')

    _ltrimText: (text) ->
        text.replace(/^\s+/g, '')

    _parseText: (text) ->
        text = @_replaceNotificationHrefs(text)
        text = @_cutCiteFromText(text)
        text = @_trimText(text)
        content = []
        @_textParser.parseText(content, text)
        return content

    _cutCiteFromText: (text) ->
        return EmailReplyParser.parse_reply(text)

class GmailBodyParser extends BaseEmailBodyParser

    _cutCiteFromDomDocument: (doc) ->
        gmail_quoted = doc.getElementsByClassName('gmail_quote')
        blockquoteCount = 0
        divGmailQoute = null
        blockquote = null
        for element in gmail_quoted
            if element.tagName.toLowerCase() == 'blockquote'
                blockquoteCount++
                blockquote = element
            divGmailQoute = element if element.tagName.toLowerCase() == 'div'
        if blockquoteCount == 1
            if divGmailQoute
                divGmailQoute.parentNode.removeChild(divGmailQoute) if divGmailQoute.parentNode
            else
                blockquote.parentNode.removeChild(blockquote) if blockquote.parentNode
        return doc


class ThunderbirdBodyParser extends BaseEmailBodyParser

    _cutCiteFromDomDocument: (doc) ->
        prefix = doc.getElementsByClassName('moz-cite-prefix').item(0)
        return doc if not prefix
        blockquoted = doc.getElementsByTagName('blockquote')
        blockquoteCount = 0
        for element in blockquoted
            blockquoteCount++ if element.getAttribute('type') == 'cite'
        return doc if blockquoteCount != 1
        prefix.parentNode.removeChild(prefix) if prefix.parentNode
        for element in blockquoted
            element.parentNode.removeChild(element) if element.parentNode and element.getAttribute('type') == 'cite'
        return doc


class AppleMailBodyParser extends BaseEmailBodyParser

    _cutCiteFromDomDocument: (doc) ->
        br = doc.getElementsByClassName('Apple-interchange-newline').item(0)
        return doc if not br
        citeDiv = br.parentNode
        return doc if not citeDiv
        blockquoted = doc.getElementsByTagName('blockquote')
        blockquoteCount = 0
        for element in blockquoted
            blockquoteCount++ if element.getAttribute('type') == 'cite'
        return doc if blockquoteCount != 1
        citeDiv.parentNode.removeChild(citeDiv) if citeDiv.parentNode
        return doc


class DefaultMailBodyParser extends BaseEmailBodyParser
    ###
    Дефолтный парсер пытается порпарсить только текстовую версию письма
    ###
    getBlipContent: (mail) ->
        return @_parseText(mail.text) if mail.text
        return @_parseHtml(mail.html) if mail.html
        @_logger.error("Mail #{mail.getId()} hasn't any body")
        return ""

    _cutCiteFromDomDocument: (doc) ->
        ###
        Заглушка
        ###
        return doc


class EmailBodyParser

    _factory: (mail) ->
        if mail.headers['message-id'] and mail.headers['message-id'].indexOf('gmail.com') != -1
            return new GmailBodyParser()
        else if mail.headers['user-agent'] and mail.headers['user-agent'].indexOf('Thunderbird') != -1
            return new ThunderbirdBodyParser()
        else if mail.headers['x-mailer'] and mail.headers['x-mailer'].indexOf('Apple Mail') != -1
            return new AppleMailBodyParser()
        else
            return new DefaultMailBodyParser()

    getBlipContent: (mail) ->
        parser = @_factory(mail)
        return parser.getBlipContent(mail)

module.exports =
    EmailBodyParser: new EmailBodyParser()
    BaseEmailBodyParser: BaseEmailBodyParser
    GmailBodyParser: GmailBodyParser
    ThunderbirdBodyParser: ThunderbirdBodyParser
    AppleMailBodyParser: AppleMailBodyParser
    DefaultMailBodyParser: DefaultMailBodyParser
    BlockParsedElementProcessor: BlockParsedElementProcessor
