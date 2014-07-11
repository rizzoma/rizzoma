url = require('url')

Conf = require('../conf').Conf
FileProcessor = require('./processor').FileProcessor
logger = Conf.getLogger('file-view')
isRobot = require('../utils/http_request').isRobot

BASE_URL = Conf.get('baseUrl')
# todo: move list with additional to BASE_URL referer hosts to the settings
ALLOWED_REFERRERS = [url.parse(BASE_URL).hostname, 'rtb-media.ru']

class FilesView
    _sendData: (req, res, data) ->
        @_clearInterval(req, res)
        if req.isXMLHttpRequest
            res.end(JSON.stringify(data))
        else
            res.end("<textarea>#{JSON.stringify(data)}</textarea>")

    _sendError: (req, res, err) ->
        response =
            error: err
        logger.warn 'sending error:', response
        @_sendData(req, res, response)

    _sendSuccess: (req, res, data) ->
        response =
            error: null
            res: data
        logger.info 'sending success:', response
        @_sendData(req, res, response)

    _sendUploadError: (req, res, err) ->
        @_sendError(req, res, err)
        if path = req.files['file']?.path
            FileProcessor.unlinkTmpFile(path)

    _setInterval: (req, res) ->
        req['__intervalId'] = setInterval ->
            res.write(' ')
        , 10000

    _clearInterval: (req, res) ->
        clearInterval(req['__intervalId']) if req['__intervalId']?

    putFile: (req, res) =>
        if not req.loggedIn or not req.user
            return @_sendUploadError(req, res, 'Permission denied. Please log in.')
        if not req.files or not (file = req.files.file) or not file.size
            return @_sendUploadError(req, res, 'File is not specified in request.')
        logger.info req.files.file
        fileId = req.body.id
        if not /^[0-9a-f]+-[0-9a-f]+-[0-9]+-[01]{1}\.[0-9]+$/i.test(fileId)
            return @_sendUploadError(req, res, 'Request id is invalid. Please reload page and try again.')
        @_setInterval(req, res)
        FileProcessor.putFile(req.user, fileId, file.path, file.name, file.type, file.size, (err, data) =>
            return @_sendUploadError(req, res, err) if err
            @_sendSuccess(req, res, fileId)
        )

    _checkReferer: (req) ->
        ###
        Проверяет, что реферер указывает на наш сервер или отсутствует.
        Нужно для показа анонимам аттачей.
        @param req: HttpRequest
        @returns: bool
        ###
        referer = req.header('Referer')
        return true if not referer or not referer.length
        hostname = url.parse(referer).hostname
        return true if hostname and hostname in ALLOWED_REFERRERS

    fileLinkRedirect: (req, res) =>
        @_getLink(req, res, FileProcessor.getFileLink)

    thumbnailLinkRedirect: (req, res) =>
        @_getLink(req, res, FileProcessor.getThumbnailLink)

    _getLink: (req, res, getter) ->
        fileId = req.params.fileId
        if not req.loggedIn or not req.user
            if not @_checkReferer(req) and not isRobot(req)
                res.statusCode = 403
                return res.end('Please sign in.')
        getter(fileId, (err, file, link) ->
            if err or file.removed
                if err
                    logger.error({err: err, fileId: file?.id})
                else
                    logger.warn("removed file #{file.id} was requested")
                res.statusCode = 404
                return res.end('Requested file was removed from storage server.')
            logger.debug "Redirecting request for file #{file.id}"
            try
                res.redirect(link)
            catch e
                logger.error e
                res.statusCode = 500
                res.end('Error occurred.')
        )

    getRemainingSpace: (req, res) =>
        if not req.loggedIn or not req.user
            return @_sendError(req, res, 'Permission denied. Please log in.')
        FileProcessor.getRemainingSpace req.user, (err, size) =>
            return @_sendError(req, res, err) if err
            @_sendSuccess(req, res, size)

exports.FilesView = new FilesView()
