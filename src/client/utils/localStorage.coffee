MicroEvent = require('./microevent')

BUFFER = 'buffer'
LASTAUTH = 'lauth'
LOGIN_COUNT_COOKIE = "cap_lc"
ENTER_COUNT = 'ec'
BLIP_READ_STATE = 'blipReadState'
CHANGE_TOPIC_LIST = "network.wave.searchBlipContent"
LINKEDIN_POPUP_SHOWED = 'lps'
REPLIES_COUNT = 'replies_count'
TOPICS_COUNT = 'topics_count'
TOPICS_CREATED = 'topics_created'
USERS_ADDED = 'users_added'
CLEAR_EXCLUDE = [LASTAUTH, LINKEDIN_POPUP_SHOWED, ENTER_COUNT, REPLIES_COUNT, TOPICS_COUNT, USERS_ADDED, TOPICS_CREATED]
# События, оповещающие об изменении прочитанности блипов будут слаться не чаще, чем указанное время
BLIP_READ_EVENT_TIMEOUT = 5 * 1000
LAST_HIDDEN_TIP_DATE = 'interface.lastHiddenTipDate'
LAST_OPENED_COLLECTION_TOPIC_ID = 'interface.collection.lastOpenedTopicId'

class LocalStorage
    constructor: ->
        @_blipReadEvents = []
        window.addEventListener('storage', @_handleEvent, false)
        
    _handleEvent: (event) =>
        @_dispatchUpdateEvent(event.key, event.oldValue, event.newValue)
        
    _dispatchEvent: (eventType, eventParams) ->
        @emit(eventType, eventParams)
        
    _dispatchUpdateEvent: (key, oldValue, newValue) ->
        unless key?
            return @_dispatchEvent('clear')
        if key is BLIP_READ_STATE
            return @_dispatchBlipReadEvent(oldValue, newValue)
        else if key is CHANGE_TOPIC_LIST
            return if newValue is null
            params = JSON.parse(newValue).value
        else params = {oldValue, newValue}
        @_dispatchEvent(key, params)

    _dispatchBlipReadEvent: (oldValue, newValue) ->
        return unless newValue
        events = JSON.parse(newValue)
        for event in events
            @_dispatchEvent(BLIP_READ_STATE, event)

    _dispatchErrorEvent: ->
        @_dispatchEvent('error')

    _setUserItem: (key, value) ->
        value = {
            userId: window.userInfo?.id
            value: value
        }
        #добавляется постоянно изменяющийся параметр к объекту, чтобы в других вкладках вызвалось событие изменения локального хранилища
        value.time = Date.now() if key is CHANGE_TOPIC_LIST
        try window.localStorage.setItem(key, JSON.stringify(value))

    _getUserItem: (key) ->
        try
            value = JSON.parse(window.localStorage.getItem(key))
        catch e
            console.warn "JSON.parse error for localStorage item, key #{key}, err: #{e}"
            return null
        return if not value
        return value.value if value.userId == window.userInfo?.id
        try window.localStorage.removeItem(key)
        null

    hasBuffer: ->
        !!@getBuffer()

    getBuffer: ->
        try window.localStorage.getItem(BUFFER)

    setBuffer: (value) ->
        oldValue = @getBuffer()
        try window.localStorage.setItem(BUFFER, value)
        @_dispatchUpdateEvent(BUFFER, oldValue, value)

    removeBuffer: ->
        oldValue = @getBuffer()
        try window.localStorage.removeItem(BUFFER)
        @_dispatchUpdateEvent(BUFFER, oldValue, null)

    getLastAuth: ->
        try window.localStorage.getItem(LASTAUTH)

    setLastAuth: (value) ->
        try window.localStorage.setItem(LASTAUTH, value)

    getTopicsCount: ->
        cnt = try window.localStorage.getItem(TOPICS_COUNT)
        cnt = 0 if not cnt
        parseInt(cnt)

    setTopicsCount: (value) ->
        try window.localStorage.setItem(TOPICS_COUNT, value)

    getUsersAdded: ->
        cnt = try window.localStorage.getItem(USERS_ADDED)
        cnt = 0 if not cnt
        parseInt(cnt)

    incUsersAdded: (delta=1) ->
        try window.localStorage.setItem(USERS_ADDED, @getUsersAdded()+delta)

    getTopicsCreated: ->
        cnt = try window.localStorage.getItem(TOPICS_CREATED)
        cnt = 0 if not cnt
        parseInt(cnt)

    incTopicsCreated: () ->
        try window.localStorage.setItem(TOPICS_CREATED, @getTopicsCreated()+1)

    getRepliesCount: ->
        cnt = try window.localStorage.getItem(REPLIES_COUNT)
        cnt = 0 if not cnt
        parseInt(cnt)

    incRepliesCount: ->
        try window.localStorage.setItem(REPLIES_COUNT, @getRepliesCount()+1)

    getEnterCount: ->
        try window.localStorage.getItem(ENTER_COUNT)

    setEnterCount: (value) ->
        try window.localStorage.setItem(ENTER_COUNT, value)

    increaseLoginCount: ->
        return if not window.userInfo?
        if window.userInfo.daysAfterFirstVisit < 22
            return if not window.firstSessionLoggedIn
            loginCount = parseInt($.cookie(LOGIN_COUNT_COOKIE) || 0)
            $.cookie(LOGIN_COUNT_COOKIE, loginCount + 1, {path: '/topic/', expires: 100})
        else
            $.cookie(LOGIN_COUNT_COOKIE, '', {path: '/topic/', expires: -1}) if $.cookie(LOGIN_COUNT_COOKIE)?

    loginCountIsMoreThanTwo: ->
        return false if not window.userInfo?
        cookieVal = $.cookie(LOGIN_COUNT_COOKIE)
        return true if not cookieVal?
        return parseInt(cookieVal) > 2

    getLoginCount: ->
        cookieVal = $.cookie(LOGIN_COUNT_COOKIE)
        return null if not cookieVal?
        return parseInt(cookieVal)

    setSearchResults: (key, value, mode) ->
        value = {savedTime: Date.now(), value: value, mode: mode}
        @_setUserItem(key, value)

    getSearchResults: (key, mode) ->
        val = @_getUserItem(key)
        return val if val and mode is val.mode

    clearSearchResult: (key) ->
        try window.localStorage.removeItem(key)

    clear: ->
        try
            for k,v of window.localStorage
                continue if k in CLEAR_EXCLUDE
                window.localStorage.removeItem(k)

    updateBlipReadState: (params) ->
        @emit(BLIP_READ_STATE, params)
        @_blipReadEvents.push(params)
        @_freeCapturedBlipReadEvents()

    _freeCapturedBlipReadEvents: ->
        return if @_nextWriteHandler?
        return if not @_blipReadEvents.length
        prevTime = @_prevWriteTime || 0
        nextTime = prevTime + BLIP_READ_EVENT_TIMEOUT
        delta = Math.max(0, nextTime - Date.now())
        @_nextWriteHandler = setTimeout(@_writeCapturedBlipReadEvents, delta)

    _writeCapturedBlipReadEvents: =>
        try window.localStorage.setItem(BLIP_READ_STATE, JSON.stringify(@_blipReadEvents))
        try window.localStorage.removeItem(BLIP_READ_STATE)
        @_blipReadEvents = []
        @_prevWriteTime = Date.now()
        @_nextWriteHandler = null
        @_freeCapturedBlipReadEvents()

    setLastHiddenTipDate: (date) ->
        @_setUserItem(LAST_HIDDEN_TIP_DATE, date)

    getLastHiddenTipDate: ->
        date = @_getUserItem(LAST_HIDDEN_TIP_DATE)
        if not date? and window.loggedIn
            date = try window.localStorage.getItem('last-hidden-tip-date')
            if date?
                @_setUserItem(LAST_HIDDEN_TIP_DATE, date)
                try window.localStorage.removeItem('last-hidden-tip-date')
        return date

    removeLastHiddenTipDate: ->
        try window.localStorage.removeItem(LAST_HIDDEN_TIP_DATE)

    _fixLastHiddenTipDate: ->
        ###
        Переводит last hidden tip date из старого формата в новый
        ###
        return if not window.loggedIn

    setLinkedinPopupShowed: -> @_setUserItem(LINKEDIN_POPUP_SHOWED, true)

    getLinkedinPopupShowed: -> @_getUserItem(LINKEDIN_POPUP_SHOWED)

    setLastCollectionTopicId: (topicId) -> @_setUserItem(LAST_OPENED_COLLECTION_TOPIC_ID, topicId)

    getLastCollectionTopicId: -> @_getUserItem(LAST_OPENED_COLLECTION_TOPIC_ID)

MicroEvent.mixin(LocalStorage)
module.exports.BLIP_READ_STATE = BLIP_READ_STATE
module.exports.CHANGE_TOPIC_LIST = CHANGE_TOPIC_LIST
module.exports.LocalStorage = new LocalStorage()