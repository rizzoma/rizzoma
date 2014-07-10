async = require('async')
Conf = require('../conf').Conf
ImportError = require('./exceptions').ImportError
CouchImportProcessor = require('./couch_processor').CouchImportProcessor
SourceSaver = require('./source_saver').SourceSaver
ImportSourceParser = require('./source_parser').ImportSourceParser
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
appVersion = Conf.getVersion()

SOURCES_LIMIT = 42

importTemplate = Conf.getTemplate().compileFile('import/index.html')
importCountTemplate = Conf.getTemplate().compileFile('import/count_of_imported.html')
externalRedirectTemplate = Conf.getTemplate().compileFile('import/external_redirect.html')
class ImportView
    ping: (req, res) =>
        if not req.loggedIn or not req.user
            return @_renderError(req, res, {type: "error", message: "AuthError"}, true)
        @_renderMessage(req, res, {type: "info", message: "Success"}, true)

    statistic: (req, res) =>
        ###
        Выводит статистику об импортируемых волнах
        ###
        params =
            loggedIn: req.loggedIn
            sessionId: req.sessionID
            messages: @_getAndRemoveSessionMessages(req)
            appVersion: appVersion
            appSignatureType: Conf.get('app').signatureType
        tasks = [
            async.apply(@_getUser, req)
            (user, callback) ->
                params.everyauth = user
                return callback(null, []) if not req.loggedIn or not user
                CouchImportProcessor.getByParticipantEmail(user.email, SOURCES_LIMIT, callback)
            (sources, callback) =>
                params.sources = @_getSourcesParam(sources)
                try
                    res.send(importTemplate.render(params))
                    callback(null)
                catch e
                    callback(e)
        ]
        async.waterfall(tasks, (err) ->
            if err
                res.send 500
                Conf.getLogger('http').error(err)
        )
    
    countOfImported: (req, res) =>
        ###
        Выводит табличку с импортированными волнами по дням
        ###
        params = {}
        tasks = [
            (callback) ->
                CouchImportProcessor.getImportedByDate(callback)
            (sources, callback) =>
                for item in sources
                    item.date = new Date(item.key[0], item.key[1]-1, item.key[2])
                params.table = sources
                try
                    res.send importCountTemplate.render(params)
                    callback(null)
                catch e
                    callback(e)
        ]
        async.waterfall(tasks, (err) ->
            if err
                Conf.getLogger('http').error(err)
                res.send 500
        )

    _getSourcesParam: (sources) ->
        psources = []
        for source, i in sources
            urlBase = 'https://wave.google.com/wave/waveref/'
            idPrefix = source.id.split('!')[0]
            idUrl = source.id.replace('_'+idPrefix, '/~').replace(/\!/g, '/')
            source.url = urlBase + idUrl
            source.title = ImportSourceParser.getWaveTitle(source.sourceData)
            source.even = 'even' if not (i % 2)
            source.lastUpdateTimestamp = new Date(source.lastUpdateTimestamp*1000)
            psources.push(source)
        return psources
        
    _getUser: (req, callback) =>
        return callback(null, null) if not req.loggedIn
        UserCouchProcessor.getById(req.user.id, callback)

    _addSessionMessage: (req, message) ->
        if not req.session.messages
            req.session.messages = []
        req.session.messages.push(message)

    _getAndRemoveSessionMessages: (req) =>
        return [] if not req.session.messages
        messages = req.session.messages
        req.session.messages = []
        return messages

    _renderError: (req, res, error, simpleResponse) ->
        return res.send(JSON.stringify(error)) if simpleResponse
        params =
            everyauth: req.user
            loggedIn: req.loggedIn
            sessionId: req.sessionID
            messages: [error]
        try
            res.send importTemplate.render(params)
        catch e
            Conf.getLogger('http').error(e)
            res.send 500

    _renderMessage: (req, res, message, simpleResponse) =>
        return res.send(JSON.stringify(message)) if simpleResponse
        @_addSessionMessage(req, message)

    _catchError: (req, res, err, simpleResponse) ->
        if err instanceof ImportError
            return @_renderError(req, res, {type: "error", message: err.name, data: err.data}, simpleResponse)
        else
            logger = Conf.getLogger()
            logger.error(err)
            return @_renderError(req, res, {type: "error", message: 'InternalError'}, simpleResponse)

    saveSource: (req, res) =>
        ###
        Сохраняет источник для импортяа волны
        ###
        simpleResponse = req.body.simpleResponse
        if not req.loggedIn or not req.user
            return @_renderError(req, res, {type: "error", message: "AuthError"}, simpleResponse)
        waveData = req.body.waveletJson
        if not waveData
            return @_renderError(req, res, {type: "error", message: "WrongParamError"}, simpleResponse)
        SourceSaver.save(req.user, waveData, (err, gWaveId) =>
            if err
                return @_catchError(req, res, err, simpleResponse)
            @_renderMessage(req, res, {type: "info", message: "Success", data: {gWaveId: gWaveId}}, simpleResponse)
            if not simpleResponse
                res.redirect(IMPORT_URL)
        )
        
    waveLinkRedirect: (req, res) =>
        domain = req.params.domain
        gWaveId = req.params.waveId
        waveletId = req.params.waveletId || "conv+root"
        blipId = req.params.blipId
        sourceId = domain + '!' + gWaveId + '_' + domain + '!' + waveletId
        CouchImportProcessor.getById(sourceId, (err, source) ->
            if err or not source.importedWaveId
                link = 'https://wave.google.com/wave/waveref/' + domain + '/' + gWaveId + '/~/' + waveletId
                link += '/' + blipId if blipId
                params =
                    url: link
                try
                    res.send externalRedirectTemplate.render(params)
                catch e
                    Conf.getLogger('http').error(e)
                    res.send 500
            else
                link = "/topic/#{source.importedWaveUrl}/"
                if blipId and source.blipIds and source.blipIds[blipId]
                    link += "#{source.blipIds[blipId]}/"
                res.redirect(link)
        )

module.exports.ImportView = new ImportView()