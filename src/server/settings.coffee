###
    Settings module. Contains all available settings with default or best fit for development values.
    First level is environment name (for running code in 'dev', 'prod'; when starting node
    this value will be got from NODE_ENV system environment variable).
    Second level is block name.
    If you want to change some settings locally you should use 'settings_local.coffee' file
    (it's added to '.gitignore'; example at file 'settings_local.coffee.template').
###
path = require('path')

redisCacheBackendOptions =
    host: 'localhost'
    port: 6379
    db: 1

module.exports.dev =
    app:
        listenPort: 8000
        waveUrl: '/topic/'
        waveEmbeddedUrl: '/embedded/'
        waveDriveUrl: '/drive/'
        # название cookie для флага о том, что пользователь согласился, что его браузер не поддерживается
        showIfUnsupportedBrowserCookie: "show_if_unsupported_browser"
        # какую подпись с версией и др. информацией о приложении показывать пользователям: 'dev', 'prod'
        signatureType: 'dev'

    # url of this site (for links in emails, XMPP, auth, ...)
    baseUrl: 'http://localhost:8000'

    db:
        main:
            type: 'cradle'
            protocol: 'http'
            hostname: '127.0.0.1'
            port: 5984
            options:
                cache: false
                #auth:
                #    username: 'root'
                #    password: 'secret'
            db: 'project_rizzoma'
            designsDir: '/src/server/couch_views/main/'
        operations:
            type: 'cradle'
            protocol: 'http'
            hostname: '127.0.0.1'
            port: 5984
            options:
                cache: false
                #auth:
                #    username: 'root'
                #    password: 'secret'
            db: 'project_rizzoma'
            designsDir: '/src/server/couch_views/operations/'

    sharejs:
        opsBeforeCommit: 1
        numCachedOps: 1
        reapTime: 1
        forceReaping: true
        maximumAge: 1000000

    ot:
        amqpOptions: {} # use default from the "amqpConnect"

    search:
        searchType: 'local' # default
        sphinxPort: 9306
        sphinxHost: 'localhost'
#        searchType: 'amqp'
#        amqpOptions: {} # use default options
#        searchTimeout: 15 # default search timeout is 15 s
#        sphinxTimeout: 10 # default SphinxSearch connect timeout is 10 s


    searchIndexer:
        indexes: [
            # выполнять каждые threshold секунд, если попадает в between: [starthour, endhour], starthour included in server offset
            {threshold: 24 * 60 * 60, between: [2, 4]},
            {threshold: 15 * 60},
            {threshold: 3}
        ]
        indexesPath: '/var/lib/sphinxsearch/data'
        docsAtOnce: 10000
        indexCommand: path.join(__dirname, '/../../bin/run_sphinx_indexer.sh')
        mergeCommand: path.join(__dirname, '/../../bin/merge_sphinx_indexes.sh')
        # backup:
        #     # выполнять каждые threshold секунд, если попадает в between: [starthour, endhour], starthour included in server offset
        #     threshold: 24 * 60 * 60
        #     between: [3, 4]
        #     command: path.join(__dirname, '/../../bin/run_sphinx_backup.sh')
        indexPrefix: 'dev' # prefix for indexes directory - allow to use one sphinxsearch with many nodes
        indexerType: 'local' # default
        # indexerType: 'amqp'
        # amqpOptions: {} # use default

    ui:
        # Константы для интерфейса пользователя
        search:
            refreshInterval:
                # Интервал обновления для списков в панели поиска
                visible: 240
                hidden: 800
                # Время обновления невидимого таба, берется на клиенте случайно из интервала
                hiddenTab:
                    lbound: 900 # Нижняя граница интервала
                    ubound: 1000 # Верхняя граница интервала

    session:
        secret: 'zQnNJ272fqRwjP0WyNAZ+UYdDOl3tO4uHz1di+9pTaMChLnl'
        key: 'connect.sid'
        cookie:
            maxAge: null # session cookie
        # /ping/ request interval, in seconds
        refreshInterval: 1200
        storeType: 'memory' # (default session store)
        # storeType: 'redis'
        storeOptions: # for redis:
            ttl: 90 * 60 # 90 minutes
            # host: 'localhost'
            # port: 6379
            # db: 1
            # pass: ''
            # prefix: 'sess:'

    socialSharing:
        url: '/!/'
        signSalt: 'MvRfesxTEVTn+uWT'
        signLength: 6
        timeout: 120

    gadget:
        enabled: true
        # URL контейнера для гаджетов Shindig без завершающего слеша.
        # (возможно, должен быть на совсем отдельном от основного домене)
        shindigUrl: 'https://d1twizu1s7sme1.cloudfront.net'

    logger:
        # настройки логгера
        defaultLoggerName: 'system'
        logLevel: 'DEBUG'
        # Число означает глубину логирования. По умолчанию в ноде 2.
        logRequest: 3
        logResponse: 3
        # Использовать X-Forwarded-For для определения ip клиента
        useXForwardedFor: true
        # Список адресов от которых принимать X-Forwarded-For
        trustedAddress: ['127.0.0.1',]
        transports:
            "*":[
                {
                    transportClass: require('./common/logger/categoried_stdout').CategoriedStdoutLogger
                    colorize: true
                    loggerNameField: 'category'
                }
#                {
#                    transportClass: require('./common/logger/graylog2').Graylog2Logger
#                    loggerNameField: 'graylogFacility'
#                    graylogHost: '127.0.0.1'
#                    graylogPort: 12201
#                    appInfo: true
#                }
            ],
            "http": [
                {
                    transportClass: require('./common/logger/categoried_stdout').CategoriedStdoutLogger
                    colorize: true
                    loggerNameField: 'category'
                    #писать али нет meta, по умолчанию писать
                    meta: false
                }
#                {
#                    transportClass: require('./common/logger/graylog2').Graylog2Logger
#                    loggerNameField: 'graylogFacility'
#                    graylogHost: '127.0.0.1'
#                    graylogPort: 12201
#                    appInfo: true
#                }
            ]


    amqpConnect:
        # Подключение к AMQP брокеру (RabbitMQ) для отправки логов, запросов на индексацию и поиск и т.д.
        # Здесь находятся настройки соединения по умолчанию. Они могут быть переписаны в search.amqpOptions и пр.
        port: 5672
        host: '127.0.0.1'
        login: 'guest'
        password: 'guest'
        vhost: '/'
        implOptions:
            reconnect: true
            reconnectBackoffStrategy: 'exponential'
            reconnectBackoffTime: 1000
            reconnectExponentialLimit: 120000

    generator:
        # id update-handler'а в базе.
        sequencerHandlerId: 'sequence/increment'
        # Префикс, нужен на будущее, если будет нужно больше одного генератора на тип.
        prefix: '0'
        # Разделитель в id.
        delimiter: '_'
        # Основание системы счисления в в которой будет представлена числовая часть id (для компактности).
        base: 32

    sockjs:
        heartbeat_delay: 25000

    contacts:
        updateThreshold: 24 * 60 * 60 # Автоматически обновляем список контактов не чаще 24 часов
        maxContactsCount: 1000 # Количество контактов, запрашиваемое у стороннего сервиса
        redirectUri: /\/auth\/(google|facebook)\/contacts\/callback/
        updateUrl: /\/contacts\/(google|facebook)\/update/
        avatarsPath: path.join(__dirname, '/../../data/avatars/')
        internalAvatarsUrl: '/avatars/'
        sources:
            google:
                apiUrl: 'https://www.google.com/m8/feeds'
                codeUrl: 'https://accounts.google.com/o/oauth2/auth'
                tokenUrl: 'https://accounts.google.com/o/oauth2/token'
                scope: 'https://www.google.com/m8/feeds'
                redirectUri: '/auth/google/contacts/callback'
                avatarsFetchingCount: 1
            facebook:
                apiUrl: 'https://graph.facebook.com'
                codeUrl: 'https://facebook.com/dialog/oauth'
                tokenUrl: 'https://graph.facebook.com/oauth/access_token'
                scope: 'friends_about_me,xmpp_login'
                redirectUri: '/auth/facebook/contacts/callback'

    #Реквизиты приложения в соответствующем провайдере для авторизации.
    auth:
        authUrl: /\/auth\/(google|facebook)\/$/
        embeddedAuthUrl: '/auth/embedded/'
        callbackUrl: /\/auth\/(google|facebook)\/callback/
        googleAuthByTokenUrl: '/auth/google-by-token/'
        logoutUrl: '/logout'
        ajaxLogoutUrl: '/ajax-logout'
        facebook:
            # application id and secret for http://localhost:8000
            # (can be obtained at https://developers.facebook.com/apps/ "Create a New App", App ID and App Secret values)
            clientID: '123'
            clientSecret: 'facebook-app-secret'
            callbackURL: '/auth/facebook/callback'
            scope: ['email']
            # override profileURL instead of profileFields because updated_time and verified can be specified in it.
            profileURL: 'https://graph.facebook.com/me?fields=id,email,first_name,gender,last_name,link,locale,name,picture,timezone,updated_time,verified'
        google:
            # application id and secret for http://localhost:8000
            # (can be obtained at https://console.developers.google.com/project "APIS&AUTH">"Credentials")
            clientID: '123'
            clientSecret: 'google-client-secret'
            callbackURL: '/auth/google/callback'
            scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']
        googleByToken:
            scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']
        password: {}

    # refresh_token для Google Drive
    gDriveConf:
        gDriveRefreshToken: ''
        updateInterval: 60 # 1 minute
        cachePath: '/tmp' # directory for googleapis discovery documents

    # топики которые создаются для только что зарегистрировавшегося пользователя
    welcomeWaves: [
        {
            # welcome topic source and owner
            sourceWaveUrl: null
            ownerUserEmail: 'support@rizzoma.com'
        }
    ]

    supportEmail: 'support@rizzoma.com'

    notification:
        # notification settings (transports settings and rules)
        transport: {}
#            smtp:
#                host: 'smtp.gmail.com'
#                port: 587
#                ssl: false
#                use_authentication: true
#                user: 'username@gmail.com'
#                pass: ''
#                from: 'username@gmail.com'
#                fromName: 'Notificator'
#            xmpp:
#                jid: 'username@gmail.com'
#                password: ''
#                idleTimeout: 30 # проверять связь (слать пинг) после такого времени неактивности соединения
#                pingTimeout: 10 # время, которое ожидаем ответа на пинг
#                connectTimeout: 30 # если за это время не удалось установить соединение,то попробуем еще раз
#            switching: {} # automatically uses smtp or facebook-xmpp (for Facebook users)
#            'facebook-xmpp': {}
        rules:
            message: ["xmpp", "switching"]
            task: ["xmpp", "switching"]
            add_participant: ["switching"]
            'import': ["smtp"]
            weekly_changes_digest: ["smtp"]
            daily_changes_digest: ["smtp"]
            announce: ["smtp"]
            first_visit: ["smtp"]
            new_comment: ["smtp"]
            merge: ["smtp"]
            access_request: ["smtp"]
            register_confirm: ["smtp"]
            forgot_password: ["smtp"]
            enterprise_request: ["smtp"]
            payment_blocked: ["smtp"]
            payment_fault: ["smtp"]
            payment_no_card: ["smtp"]
            payment_success: ["smtp"]

    # генерация хэша в письме добавления, для предупреждения, что добавили по одному email, а заходит с другого
    referalEmailSalt: 'xt5IzUDyZbPPzNaxmZNxBKEz5gG8mmFniVlY59HWCcnCowuG'

    # получение ответов на письма о меншенах, тасках и реплаях
    replyEmail: "username@gmail.com" # подставлять этот адрес вместе с id и хэшами в заголовок Reply-To
    emailReplyFetcher:
        imap:
            username: 'username@gmail.com'
            password: ''
            host: 'imap.gmail.com',
            port: 993,
            secure: true

    siteAnalytics:
        googleAnalytics:
            id: 'UA-22635528-4'
            # domainName: 'rizzoma.com'
        rtbm:
            id: '35A57B3B'
            loggedInId: '45CF8FB4'
        # mixpanel:
        #    id: ''
        # yandexMetrika:
        #    id: ''

    files:
        type: 'local'
        uploadSizeLimit: 50 * 1024 * 1024
        # Настройки файлового хранилища Amazon S3:
        #   accessKeyId = Публичный ключ доступа
        #   secretAccessKey = Приватный ключ доступа
        #   awsAccountId = Идентификатор аккаунта (обязателен для awssum, но можно отдать любую непустую строку)
        #   region = регион для амазона. Взять соответствующую константу из файла ./node_modules/awssum/lib/amazon/amazon.js
        #       ('us-east-1' | 'us-west-1' | 'us-west-2' | 'eu-west-1' | 'ap-southeast-1' | 'ap-northeast-1' | 'sa-east-1' | 'us-gov-west-1)
        #   buckets = названия корзин, в которые будут складываться файлы
        #   linkExpiration = время жизни раздаваемых ссылок в секундах
        # type - тип процессора файлов: 'local' | 's3'
        # uploadSizeLimit - квота на закачку файлов
        #s3:
        #   accessKeyId: ''
        #   secretAccessKey: ''
        #   awsAccountId: ''
        #   region: ''
        #   buckets: {
        #       files: ''
        #       avatars: ''
        #       store: ''
        #   }
        #   linkExpiration: 60
        #local: {}

    cache: {} # not using by default
#        user:
#            backend: 'RedisLruBackend'
#            backendOptions: redisCacheBackendOptions
#        blip:
#            backend: 'RedisLruBackend'
#            backendOptions: redisCacheBackendOptions
#        wave:
#            backend: 'MemoryLruBackend'
#            backendOptions: {cacheSize: 200}
#        op:
#            backend: 'MemoryLruBackend'
#            backendOptions: {cacheSize: 500}
#        tipList:
#            backend: 'MemoryLruBackend'
#            backendOptions: {cacheSize: 1}
#        urlAlias:
#            backend: 'RedisLruBackend'
#            backendOptions: redisCacheBackendOptions

    hangout:
        title: 'Rizzoma'
        appId: '286807350752'
        devMode: true

    api:
        rest:
            version: 1
        'export':
            version: 1

    'export':
        # Путь к директории, где хранятся сформированные архивы
        # Не забудьте поправить скрипт для очистки и конфигурацию веб-сервера
        archivePath: path.join(__dirname, '/../../lib/export/')

    sitemap:
        destinationPath: path.join(__dirname, '/../../lib/sitemap/')

    staticSrcPath: path.join(__dirname, '/../static/')

    payment:
        getMonthTeamTopicTax: 500 #центы
        apiPublicKey: ''

    teamTopicTemplate: #Шаблон для командных топиков
        url: null

    accountsMerge:
        emailConfirmCallbackUrl: /accounts_merge/
        oauthConfirmUrl: /\/accounts_merge\/(google|facebook)\/$/
        oauthConfirmCallbackUrl: /\/accounts_merge\/(google|facebook)\/callback/
        google:
            callbackURL: '/accounts_merge/google/callback'
        facebook:
            callbackURL: '/accounts_merge/facebook/callback'

    store:
        itemsInstalledByDefault: []
