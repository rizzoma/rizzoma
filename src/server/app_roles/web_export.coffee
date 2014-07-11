###
Роль для приложения экспорта.
Выдача топиков в разных форматах.
###

async = require('async')
Conf = require('../conf').Conf
anonymous = require('../user/anonymous')
loadMarkup = require('../export/controller').loadMarkup
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
getFileName = require('../export/utils').getFileName
{toHtml, toEmbeddedHtml, toJson} = require('rizzoma-export')
app = require('./web_base').app

logger = Conf.getLogger('export')

getTimeOffset = (req, user) ->
    if 'time_offset' of req.query
        offset = req.query.time_offset
        return if isNaN(offset) then 0 else parseInt(offset)
    if user.timezone
        return user.timezone * 3600
    return 0

getConvertFunction = (type) ->
    if type is 'html'
        return toHtml
    if type is 'embedded_html'
        return toEmbeddedHtml
    if type is 'json'
        return toJson
    return null

getContentType = (type) ->
    if type is 'html' or type is 'embedded_html'
        return 'text/html; charset=utf-8'
    if type is 'json'
        return 'application/json; charset=utf-8'
    return null

url = Conf.getApiTransportUrl('export')
app.get(new RegExp("^#{url}([a-f0-9]+)/(json|html|embedded_html)/$"), (req, res) ->
    [waveUrl, type] = req.params
    convert = getConvertFunction(type)
    if not convert
        res.send(404)
        return
    user = req.user
    funcs = [
        (callback) ->
            if user
                UserCouchProcessor.getById(user.id, callback)
            else
                callback(null, anonymous)
        (user, callback) ->
            loadMarkup(user, waveUrl, (error, markup) ->
                offset = getTimeOffset(req, user)
                callback(error, markup, offset)
            )
    ]
    async.waterfall(funcs, (error, markup, offset) ->
        if error
            return res.send(404) if error.code == "wave_document_does_not_exists"
            # todo: как разделять незалогиненных (403) и тех, кому запрещён доступ в топик (403). Делать разный текст ошибки?
            return res.send(403) if error.code == "wave_anonymous_permission_denied" or error.code == "wave_permission_denied"
            logger.error("Topic export error (url #{waveUrl}, to #{type})", {error: error, userId: user?.id})
            return res.send(500)
        res.header('Content-Type', getContentType(type))
        if 'no_download' not of req.query
            fileName = getFileName(markup.title or waveUrl, type, offset)
            res.header('Content-Disposition', 'attachment; filename="' + fileName + '"')
        body = convert(markup, {offset})
        res.send(body)
    )
)
