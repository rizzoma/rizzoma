###
Обертка над history.js, разбирает state'ы на waveId, blipId и не вызывает обработчики,
если был сделан replaceLastState
###

self = module.exports = {}
PREFIX = window.PREFIX
WAVE_PREFIX = window.WAVE_URL_PREFIX
EMBEDDED_PREFIX = window.WAVE_EMBEDDED_URL_PREFIX
IS_EMBEDDED = PREFIX is EMBEDDED_PREFIX
EMBEDDED_AUTH_URL = window.WAVE_EMBEDDED_AUTH_URL
GDRIVE_PREFIX = window.WAVE_DRIVE_PREFIX
require('./microevent').mixin(module.exports)
urlRe = new RegExp("((https?://#{window.HOST})?((#{WAVE_PREFIX}|#{EMBEDDED_PREFIX}|#{GDRIVE_PREFIX})" +
        "(?:([a-z0-9]{1,32})/?)?)(?:([a-z0-9_]{1,32})/?)?)")
statesToSkip = {} # Список состояний, следующую обработку которых нужно пропустить.
lastProcessedUrl = null
lastProcessedWaveId = null

getUrl = (waveId, blipId) ->
    url = "#{PREFIX}#{waveId}/"
    url += "#{blipId}/" if blipId
    # Используется для аналитики
    url += document.location.search || ''
    return url

self.parseUrlParams = parseUrlParams = (url) ->
    res = urlRe.exec(url) || []
    {url: res[0], host:res[2], waveUrl: res[3], waveId: res[5], serverBlipId: res[6]}

getSkippedId = ->
    id = Math.random()
    statesToSkip[id] = true
    return id

processStateChange = (callback, params) ->
    state = History.getState()
    id = state.data.id
    {url, waveId, serverBlipId} = params || parseUrlParams(state.url)
    if id and statesToSkip[id]
        delete statesToSkip[id]
    else if lastProcessedUrl isnt url
        callback(waveId, serverBlipId)
    lastProcessedUrl = url
    lastProcessedWaveId = waveId
    return false

processStateChangeWithAnalytics = (callback) ->
    params = parseUrlParams(History.getState().url)
    {url, waveId, waveUrl} = params
    if not waveId and lastProcessedUrl isnt url
        track = if window.loggedIn then waveUrl else '/unauthorized'+waveUrl
        _gaq.push(['_trackPageview', track])
    processStateChange(callback, params)

self.navigateTo = (waveId, serverBlipId) ->
    ###
    Записываем новое состояние в историю браузера
    ###
    oldState = History.getState()
    url = getUrl(waveId, serverBlipId)
    return if oldState.url == url
    if lastProcessedWaveId isnt waveId
        History.pushState(null, oldState.title, url)
    else
        History.replaceState(null, oldState.title, url)

self.changeBlipId = (serverBlipId) ->
    ###
    Переход к другому блипу.
    @param serverBlipId: string, указывается в url
    ###
    lastState = History.getState()
    {waveId} = parseUrlParams(lastState.url)
    return if not waveId
    url = getUrl(waveId, serverBlipId)
    History.replaceState({id: getSkippedId()}, lastState.title, url)

self.init = (callback) ->
    ###
    Вызывается, когда код готов обработать последнее состояние от прошлого запуска
    ###
    state = History.getState()
    processStateChange(callback) # Иногда statechange не срабатывает, приходится передавать сюда и вызывать callback
    History.Adapter.bind window, 'statechange', ->
        processStateChangeWithAnalytics (args...) ->
            self.emit('statechange', args...)
    History.replaceState(null, state.title, state.url)

self.setPageTitle = (title=false) ->
    window.title.topicTitle = title if title
    unreadCount = if window.title.unreadTopicsCount > 0 then "(#{window.title.unreadTopicsCount}) " else ''
    title = "#{unreadCount}#{window.title.topicTitle}#{if window.title.topicTitle then ' - ' else ''}#{window.title.postfix}"
    lastState = History.getState()
    window.History.replaceState({id: getSkippedId()}, title, lastState.url)

self.removeAnalytics = ->
    ###
    Убирает из url метки, необходимые для аналитики
    ###
    self.analyticsRemoved = yes
    state = History.getState()
    {url} = parseUrlParams(state.url)
    window.History.replaceState({id: getSkippedId()}, state.title, url)

self.getCurrentParams = ->
    parseUrlParams(History.getState().url)

self.getUrlParams = (url) ->
    parseUrlParams(url)

self.isEmbedded = -> IS_EMBEDDED

self.isGDrive = -> PREFIX is GDRIVE_PREFIX

self.getEmbeddedPrefix = -> EMBEDDED_PREFIX

self.getWavePrefix = -> WAVE_PREFIX

self.getPrefix = -> PREFIX

self.getLoginRedirectUrl = ->
    return EMBEDDED_AUTH_URL if IS_EMBEDDED
    url = document.location.pathname + document.location.hash
    return url if document.location.search.search(/\?notice=/) != -1
    return url + document.location.search
