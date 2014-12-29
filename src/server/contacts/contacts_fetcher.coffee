_ = require('underscore')
async = require('async')
request = require('request')
tls = require('tls')
fs = require('fs')
pathExists = fs.exists or require('path').exists #for node < 0.7
querystring = require('querystring')

Conf = require('../conf').Conf
ContactsConf = Conf.get('contacts')
HashUtls = require('../utils/hash_utils').HashUtls
formatAsISODate = require('../../share/utils/datetime').formatAsISODate

NotImplementedError = require('../../share/exceptions').NotImplementedError
MAX_CONTACTS_COUNT = ContactsConf.maxContactsCount

class OAuthUtils
    ###
    OAuth utils.
    ###
    constructor: (@_clientId, @_clientSecret, @_apiUrl, @_codeUrl, @_tokenUrl) ->

    getAuthorizeUrl: (params={}) ->
        ###
        Generate url for access code request.
        @returns: string
        ###
        params.client_id = @_clientId
        return "#{@_codeUrl}?#{querystring.stringify(params)}"

    getRedirectUri: (req, uri) ->
        protocol = if req.connection.server instanceof tls.Server or req.headers['x-forwarded-proto'] == 'https' then 'https' else 'http'
        host = req.headers.host
        return "#{protocol}://#{host}#{uri}"

    getAccessToken: (code, params={}, callback) ->
        ###
        Retrieve accessToken by code.
        @param code: string
        @param params: object
        @param callback: function(err, string)
        ###
        params.client_id = @_clientId
        params.client_secret = @_clientSecret
        params.code = code
        requestParams =
            url: @_tokenUrl
            headers: {'Content-Type': 'application/x-www-form-urlencoded'}
            body: querystring.stringify(params)
        request.post(requestParams, (err, res, body) ->
            parsedBody = {}
            try
                parsedBody = JSON.parse(body)
            catch e #OAuth 2.05 fallback
                parsedBody = querystring.parse(body)
            accessToken = parsedBody.access_token
            callback(not accessToken, accessToken)
        )


class ContactsFetcher
    ###
    Fetch data from source contacts API (base class).
    ###
    constructor: (@_sourceName) ->
        @_conf = Conf.getContactsConfForSource(@_sourceName)
        @_logger = Conf.getLogger('contacts')
        appAccount = Conf.getAuthConf()[@_sourceName]
        @_oauthConnector = new OAuthUtils(
            appAccount.clientID,
            appAccount.clientSecret,
            @_conf.apiUrl,
            @_conf.codeUrl,
            @_conf.tokenUrl
        )

    getAccessToken: (req, res, params={}) ->
        url = @_oauthConnector.getAuthorizeUrl(params)
        res.redirect(url)

    _getRedirectUri: (req) ->
        return @_oauthConnector.getRedirectUri(req, @_conf.redirectUri)

    _getScope: (source) ->
        return  @_conf.scope

    onAuthCodeGot: (req, res, params={}, callback) ->
        code = req.param('code')
        return callback('access_denied') if not code and req.param('error') == 'access_denied'
        return callback('no_code') if not code
        @_oauthConnector.getAccessToken(code, params, callback)

    fetchAllContacts: (accessToken, locale, callback) ->
        ###
        Retrieve all user contacts.
        @param accessToken: string
        @param locale: string
        @param callback: function
        ###
        throw new NotImplementedError()

    fetchContactsFromDate: (accessToken, date, locale, callback) ->
        ###
        Retrieve only contacts that were changed after the specified date.
        @param accessToken: string
        @param date: int (unix time in seconds)
        @param locale: string
        @param callback: function
        ###
        throw new NotImplementedError()

    _doContactsRequest: (requestParams, callback) ->
        ###
        Request contacts from source API.
        @param requestParams: object
        @param callback: function
        ###
        _.extend(requestParams, {jar: false})
        request.get(requestParams, (err, res, body) =>
            return callback(err) if err
            try
                json = JSON.parse(body)
            catch e
                @_logger.error("Can not parse contacts response json", [requestParams, body, e])
                return callback(e)
            callback(null, json)
        )


AVATAR_PATH_MODE = '0755'
MIN_REQUESTS_INTERVAL = 10
MAX_REQUESTS_INTERVAL = 6000
CLEAR_TIMER_INTERVAL = 60000

class GoogleContactsFetcher extends ContactsFetcher
    constructor: () ->
        super('google')
        @_avatarsPath = ContactsConf.avatarsPath
        @_requestsInterval = MIN_REQUESTS_INTERVAL
        @_clearRequestsIntervalTimer = null
        @_requestQueue = async.queue(@_fetchAvatarWorker, @_conf.avatarsFetchingCount)

    getAccessToken: (req, res) ->
        params =
            response_type: 'code'
            redirect_uri: @_getRedirectUri(req)
            scope: @_getScope()
        super(req, res, params)

    onAuthCodeGot: (req, res, callback) ->
        params =
            grant_type: 'authorization_code'
            redirect_uri: @_getRedirectUri(req)
        super(req, res, params, callback)

    fetchAllContacts: (accessToken, locale, callback) ->
        @_doContactsRequest(accessToken, null, callback)

    fetchContactsFromDate: (accessToken, date, locale, callback) ->
        formattedDate = formatAsISODate(date)
        @_doContactsRequest(accessToken, {'updated-min': formattedDate}, callback)

    _doContactsRequest: (accessToken, query={}, callback) ->
        commonQuery =
            alt: 'json'
            'max-results': MAX_CONTACTS_COUNT
        requestParams =
            url: "#{@_conf.apiUrl}/contacts/default/full"
            headers: {Authorization: "OAuth #{accessToken}", 'GData-Version': '3.0'}
            qs: _.extend(commonQuery, query)
        super(requestParams, callback)

    getUserContactsAvatarsPath: (contactsId, callback) ->
        ###
        Create directory for user contacts' avatars and return path.
        @param contactsId: string (id property of user ContactsList model)
        @param callback: function
        ###
        path = "#{@_avatarsPath}#{contactsId}/"
        pathExists(path, (exists) ->
            return fs.mkdir(path, AVATAR_PATH_MODE, (err) ->
                callback(err, path)
            ) if not exists
            callback(null, path)
        )
    fetchAvatars: (accessToken, toFetch, path, onAvatarLoad, callback) =>
        ###
        Retrieve the list of avatars.
        @param accessToken: string
        @param toFetch: array [{email, avatarUrl},...]
        @param path string - куда сохранить:
        @param onAvatarLoad function(err, email, fileName) - will be called after each avatar load
        @param callback: function(err) - will be called after all avatars have been loaded
        ###
        @_clearRequestInterval()
        tasks = []
        for toFetchElement in toFetch
            {email, avatarUrl} = toFetchElement
            tasks.push(do(email, avatarUrl) =>
                return (callback) =>
                    @_fetchAvatar(accessToken, avatarUrl, path, email, (err, fileName) =>
                        onAvatarLoad(email, fileName) if not err
                        @_logger.warn("Error while fetching avatar: #{err}", {email, avatarUrl}) if err
                        callback(null)
                    )
            )
        async.parallel(tasks, callback)

    _fetchAvatar: (accessToken, avatarUrl, path, email, callback) ->
        @_requestQueue.push({accessToken, avatarUrl, path, email}, (err, fileName) =>
            requestsInterval = @_requestsInterval
            if err == 503
                requestsInterval <<= 1
                if requestsInterval > MAX_REQUESTS_INTERVAL
                    return callback(new Error('Skipping avatar, requests interval exceeded max value'))
                @_requestsInterval = requestsInterval
                return @_fetchAvatar(accessToken, avatarUrl, path, email, callback)
            if not err
                requestsInterval >>= 1
                @_requestsInterval = requestsInterval if requestsInterval > MIN_REQUESTS_INTERVAL
            callback(err, fileName)
        )

    _fetchAvatarWorker: (args, callback) =>
        ###
        Retrieve one avatar and write to disk (@see: GoogleContactsFactory).
        @params accessToken: string
        @param avatarUrl: string
        @params path: string
        @param email: string
        @param callback: function
        ###
        {accessToken, avatarUrl, path, email} = args
        requestParams =
            url: avatarUrl
            headers: {Authorization: "OAuth #{accessToken}", 'GData-Version': '3.0'}
            jar: false
            encoding: null
        onTimeout = () =>
            request.get(requestParams, (err, resp, body) =>
                statusCode = resp.statusCode
                return callback(err or statusCode) if err or statusCode >= 400
                [path, fileName] = @_getFullAvatarPath(path, email)
                fs.writeFile(path, body, (err) ->
                    callback(err, fileName)
                )
            )
        setTimeout(onTimeout, @_requestsInterval)

    _clearRequestInterval: () ->
        clearTimeout(@_clearRequestsIntervalTimer)
        onTimeout = () ->
            @_requestsInterval = MIN_REQUESTS_INTERVAL
        @_clearRequestsIntervalTimer = setTimeout(onTimeout, CLEAR_TIMER_INTERVAL)

    removeContactsAvatar: (path, emails) ->
        ###
        Remove avatars from disk.
        @param path: string
        @param emails: array
        ###
        return if not path
        tasks = []
        for email in emails
            [path, fileName] = @_getFullAvatarPath(path, email)
            tasks.push(do(path) =>
                return (callback) =>
                    fs.unlink(path, (err) =>
                        @_logger.warn("Can not remove avatar #{path}: #{err}")
                        callback(null)
                    )
            )
        async.parallel(tasks)

    _getFullAvatarPath: (path, email) ->
        fileName = HashUtls.getSHA1Hash(email)
        return ["#{path}#{fileName}", fileName]


class FacebookContactsFetcher extends ContactsFetcher
    constructor: () ->
        super('facebook')

    getAccessToken: (req, res) ->
        params =
            redirect_uri: @_getRedirectUri(req)
            scope: @_getScope()
        super(req, res, params)

    onAuthCodeGot: (req, res, callback) ->
        params =
            redirect_uri: @_getRedirectUri(req)
        super(req, res, params, callback)

    fetchAllContacts: (accessToken, locale, callback) ->
        @_doContactsRequest(accessToken, null, locale, callback)

    fetchContactsFromDate: (accessToken, date, locale, callback) ->
        @_doContactsRequest(accessToken, {since: date}, locale, callback)

    _doContactsRequest: (accessToken, query={}, locale, callback) ->
        commonQuery =
            access_token: accessToken
            limit: MAX_CONTACTS_COUNT
            fields: "username,name"
        commonQuery.locale = locale if locale
        requestParams =
            url: "#{@_conf.apiUrl}/me/friends"
            qs: _.extend(commonQuery, query)
        super(requestParams, callback)

module.exports=
    FacebookContactsFetcher: new FacebookContactsFetcher()
    GoogleContactsFetcher: new GoogleContactsFetcher()
