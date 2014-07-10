fs = require('fs-plus')
_ = require('underscore')
express = require('express')
everycache = require('everycache')
swig  = require('swig')
path = require('path')
winston = require('winston')
CategoriedStdoutLogger = require('../common/logger/categoried_stdout').CategoriedStdoutLogger
StrUtils = require('../../share/utils/string')


class Conf
    ###
    Окружение, в котором запущен сервер: хранение настроек, методы для работы с ними, возвращение соединений с БД и т.д.
    ###
    constructor: (@settings) ->
        @_db = {}
        @_loggerConf = @_initLogger()
        @_caches = {}
        @_version = null
        # пул логгеров
        @_loggers = {}

        # Настройка шаблонизатора
        swig.init
            allowErrors: true,
            autoescape: true,
            encoding: 'utf8',
            filters: require('../templates/filters'),
            tags: {},
            extensions: {},
            tzOffset: 0
            root: @getTemplateRootDir()

    getTemplateRootDir: () =>
        versionedTemplatesRootDir = path.join(__dirname, '/../../../lib/templates')
        if fs.existsSync(versionedTemplatesRootDir)
            return versionedTemplatesRootDir
        return path.join(__dirname, '/../templates')

    getTemplate: () ->
        ###
        Возвращает обеъект шаблонизатора. У него есть методы compileFile(filename), compileString(templateString)
        @return swig
        ###
        return swig

    get: (key) ->
        ###
        Возвращает значение из конфига по ключу (только первый уровень объекта конфигурации).
        @param {String} key ключ конфига
        ###
        if key of @settings
            return @settings[key]
        else
            throw new Error("No #{key} in settings")

    getDbConf: (connName) ->
        ###
        Возвращает настройки для указанного соединения с БД.
        @param {String} connName название соединения в конфиге
        ###
        conf = @get('db')
        if connName not of conf
            throw new Error("No settings for db connection '#{connName}'")
        return conf[connName]

    getDb: (connName) ->
        ###
        Возвращает соединение с БД.
        При первом обращении создает это соединение.
        @param {String} connName название соединения в конфиге
        TODO: выделить метод getDbConnection, чтобы можно было доступиться к методам работы с сервером БД
        TODO: вынести все методы работы с БД из Conf в отдельный модуль
        ###
        dbConf = @getDbConf(connName)

        return @_db[connName] if @_db[connName]

        if dbConf.type == 'cradle'
            cradle = require('cradle')
            connection = new cradle.Connection("#{dbConf.protocol}://#{dbConf.hostname}", dbConf.port, dbConf.options)
            return @_db[connName] = connection.database(dbConf.db)
        else
            throw new Error("Unknown db type #{dbConf.type}")

    getDbUrl: (connName) ->
        ###
        Возвращает строку коннекта к базе данных (URL), формат отличается в зависимости от типа базы данных.
        @param {String} connName название соединения в конфиге
        ###
        dbConf = @getDbConf(connName)

        if dbConf.type == 'cradle'
            u =
                protocol: dbConf.protocol
                hostname: dbConf.hostname
                port: dbConf.port
                pathname: dbConf.db
            if dbConf.options.auth
                u.auth = "#{dbConf.options.auth.username}:#{dbConf.options.auth.password}"
            return require('url').format(u)
        else
            throw new Error("Unknown db type #{dbConf.type}")

    getSessionConf: () ->
        ###
        Возвращает параметры для connect's session middleware, инициализирует хранилище для сессий
        @return: object
        ###
        return @_sessionConf if @_sessionConf
        @_sessionConf = @get('session')

        @_sessionConf.cookie.maxAge *= 1000 if @_sessionConf.cookie.maxAge
        @_sessionConf.refreshInterval = @_sessionConf.refreshInterval*1000

        # session cookie name (key)
        @_sessionConf.key or= "connect.sid"

        # supported stores: memory, redis (memcache and others can be added)
        @_sessionConf.storeType or= "memory"
        switch @_sessionConf.storeType
            when "memory"
                @_sessionConf.store = new(require('express').session.MemoryStore)
            when "redis"
                RedisStore = require('connect-redis')(require('express'))
                @_sessionConf.store = new RedisStore(@_sessionConf.storeOptions || {})
            else
                throw new Error("Unsupported connect session store type: #{@_sessionConf.storeType}")

        # fingerprint по умолчанию возвращает user-agent, однако мы хотим использовать
        # сессии в websocket-соединениях, в которых user-agent не передается
        @_sessionConf.fingerprint = -> ''
        return @_sessionConf

    getCache: (type) ->
        cache = @_caches[type]
        return cache if cache
        try
            settings = @get('cache')[type]
            throw new Error("No settings for cache type '#{type}'") if not settings
        catch err
            #process.stderr.write(err)
            return null
        try
            cache = everycache.getCache(settings)
        catch err
            #process.stderr.write(err)
            return null
        return @_caches[type] = cache

    getSearchConf: () ->
        ###
        Возвращает параметры для поискового сервера.
        ###
        return @get('search')

    getSearchIndexerConf: () ->
        ###
        Возвращает параметры для поискового сервера.
        ###
        return @get('searchIndexer')

    getSphinxIndexPrefix: () ->
        return @getSearchIndexerConf().indexPrefix or 'dev'

    getSearchPlugins: () ->
        ###
        Возвращает параметры плагинов для поиска.
        ###
        return @get('searchPlugins')

    getAmqpConf: () ->
        ###
        Настройки для подключения к AMQP брокеру.
        ###
        return @get('amqpConnect')

    getOtConf: () ->
        ###
        Настройки для ot процессора.
        ###
        otConf = @get('ot')
        #Суффикс для имени очереди, которую слушает процесс.
        #Необходимо обеспечить уникальные названия очередей для каждого процесса, но эти названия не должны меняться при
        #перезапуске процесса. FRONTEND_QUEUE_SUFFIX - нужна только процессам, обслуживающим подписки пользователей.
        otConf.frontendQueueSuffix = process.env.FRONTEND_QUEUE_SUFFIX
        range = process.env.BACKEND_ID_RANGE
        otConf.backendIdRange = _.uniq(range.split(',')) if range
        return otConf

    setServerAsOtBackend: () ->
        @get('ot').isBackend = true

    getAppListenPort: () ->
        ###
        Возвращает порт, на котором должен принимать соединения HTTP-сервер.
        Значение берется из переменной окружения LISTEN_PORT, из настроек (app.listen_port),
        или возвращает значение по умолчанию (8000).
        ###
        return process.env.LISTEN_PORT || @get('app').listenPort || 8000

    getAppRoles: () ->
        ###
        Возвращает список ролей, с которыми было запущено приложение.
        Значения берутся из переменной окружения APP_ROLES, разделены запятыми.
        По умолчанию возвращает ["default"].
        @return: array
        ###
        return (process.env.APP_ROLES || "default").split(',')

    getAppName: () ->
        ###
        Возвращает название приложения, берется из переменной окружения
        ###
        return process.env.APP_NAME

    getWaveUrl: () ->
        return @get('app').waveUrl

    getWaveEmbeddedUrl: ->
        return @get('app').waveEmbeddedUrl

    getWaveDriveUrl: ->
        return @get('app').waveDriveUrl

    getTagSearchUrl: ->
        return '/tag/'

    getLoggerConf: () ->
        log_config = @get('logger')
        if process.env.LOG_LEVEL and process.env.LOG_LEVEL != ''
            log_config.logLevel = process.env.LOG_LEVEL
        return log_config

    getGeneratorConf: () ->
        return @get('generator')

    getAuthConf: () ->
        return @get('auth')

    getVersionInfo: () =>
        ###
        Версия запущенного приложения, название бранча, время билда.
        ###
        return @_version unless @_version is null

        @_version = {}
        try
            version = require('../version')
            if version
                {version, branch} = version
                branch = branch?.replace(/^trunk$|^master$|^[\d_]+/, "") # simplify branch name
                branch = if branch then "/#{branch}" else ""
                versionString = "#{version or "-"}#{branch}"
                @_version = {version, branch, versionString}
        return @_version

    getVersion: () =>
        ###
        Версия запущенного приложения
        @returns string
        ###
        return @getVersionInfo().version || ''

    _initLogger: () ->
        ###
        Инициализируем конфиг логгера
        ###
        return @getLoggerConf()

    getLogger: (loggerName=@_loggerConf.defaultLoggerName) ->
        ###
        logger
        ###
        return @_loggers[loggerName] if @_loggers[loggerName]
        transports = null
        if @_loggerConf.transports
            transports = @_loggerConf.transports[loggerName]
            transports = @_loggerConf.transports["*"] if not transports
        # по умолчанию добавим наш логгер в стдаут
        if not transports or not transports.length
            transports = [{
                transportClass: CategoriedStdoutLogger
                colorize: true
                loggerNameField: 'category'
            }]
        logLevel = @_loggerConf.logLevel.toLowerCase()
        opts = { transports: [] }
        for topts in transports
            ttopts = _.clone(topts)
            transportClass = topts.transportClass
            delete ttopts.transportClass
            ttopts.level = logLevel
            if topts.loggerNameField
                facility = loggerName
                appName = @getAppName()
                if topts.appInfo
                    facility = "#{appName}.#{facility}" if appName
                    ttopts["facilityApp"] = appName
                    ttopts["facilityCategory"] = loggerName
                    ttopts["facilityPid"] = process.pid
                ttopts[topts.loggerNameField] = facility
                delete ttopts.loggerNameField
            opts.transports.push(new transportClass(ttopts))
        logger = winston.loggers.add(loggerName, opts)
        logger.setLevels(winston.config.syslog.levels)
        logger.level = logLevel
        logger.warn = logger.warning
        @_loggers[loggerName] = logger
        return logger

    getAuthSourceConf: (source) ->
        return @get('auth')[source]

    getStorageProcessor: (client)->
        filesConf = @get('files')
        switch filesConf.type
            when 'local'
                LocalStorageProcessor = require('../file/local/processor').LocalStorageProcessor
                return new LocalStorageProcessor()
            when 's3'
                s3Conf = filesConf.s3
                bucketName = s3Conf.buckets?[client]
                throw new Error('Missing S3 tokens') if not s3Conf or not s3Conf.accessKeyId or
                        not s3Conf.secretAccessKey or not s3Conf.awsAccountId or not s3Conf.region or
                        not bucketName or not s3Conf.linkExpiration
                S3StorageProcessor = require('../file/s3/processor').S3StorageProcessor
                return new S3StorageProcessor(s3Conf.accessKeyId, s3Conf.secretAccessKey,
                        s3Conf.awsAccountId, s3Conf.region, bucketName, s3Conf.linkExpiration)
            else
                throw new Error("Problem with settings: unknown files.type '#{filesConf.type}'")

    getUploadSizeLimit: ->
        @get('files').uploadSizeLimit

    getNotificationConf: () ->
        ###
        Возвращает объект настроек нотификаций
        ###
        conf = @get('notification') || {}
        conf.rules = conf.rules or {}
        conf.hasTypeRules = (type) ->
            return not _.isEmpty(conf.rules) and conf.rules[type] and conf.rules[type].length
        conf.getTypeRules = (type) ->
            return [] if not conf.hasTypeRules(type)
            return conf.rules[type]
        conf.getCommunicationTypes = () ->
            rules = conf.rules
            res = {}
            for notificationType, transports of rules
                communicationTypes = {}
                for transport in transports
                    className = StrUtils.toCamelCase(transport) + "Transport"
                    communicationType = require("../notification/transport/" + transport)[className].getCommunicationType()
                    communicationTypes[communicationType] = communicationType
                res[notificationType] = _.keys(communicationTypes)
            return res
        return conf

    getGDriveConf: ->
        @get('gDriveConf')

    getHangoutConf: () ->
        @get('hangout')

    getApiConf: (transport) ->
        return @get('api')[transport]

    getApiTransportUrl: (transport) ->
        transportConf = @get('api')[transport]
        return if not transportConf
        return "/api/#{transport}/#{transportConf.version}/"

    getReferalEmailSalt: () ->
        return @get('referalEmailSalt')

    getContactsConfForSource: (sourceName) ->
        return @get('contacts').sources[sourceName]

    getExportConf: ->
        return @get('export')

    getStoreItemsInstalledByDefalult: () ->
        return @get('store').itemsInstalledByDefault or []

    getPaymentConf: () ->
        return @get('payment')

    getSitemapConf: () ->
        return @get('sitemap')

module.exports = Conf
