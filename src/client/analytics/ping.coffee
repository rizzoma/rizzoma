History = require('../utils/history_navigation')
localStorage = require('../utils/localStorage').LocalStorage
StyleForChangedPopup = require('./style_for_auto_popup').renderStyleForAutoPopup
HeaderTextForAutoPopup = require('./style_for_auto_popup').renderHeaderTextForAutoPopup

splitTmpl = ->
    div {
        style: "margin:10px auto;
        margin: 30px 0 -70px 0;
        font-size: 22px;
        font-family: PFAgoraSansProLightRegular, Helvetica, Arial;
        color: white;
        position: relative;
        z-index: 4;"
    }, ->
        if @v1
            div "Sign in to view and comment"
        else
            div "Anonymous access is disabled"
            div "Sign in to view the discussion"

class PingAnalytics
    constructor: ->
        $(document).ready =>
            @_trackNewVisit()
            @_updateLoginCount() if window.loggedIn
            if not window.loggedIn
                @_createAutoPopupSplitTest()
                @_createAuthSplitTest()

    _createAutoPopupSplitTest: ->
        return if History.isEmbedded()
        willShowPopup = Math.round(Math.random()) is 0
        if willShowPopup
            _gaq.push(['_setCustomVar', 4, 'auto popup split test', 'popup was showed', 2])
        else
            _gaq.push(['_setCustomVar', 4, 'auto popup split test', 'popup was not showed', 2])

        setTimeout(()->
            if willShowPopup and !window.AuthDialog.visible()
                window.AuthDialog.initAndShow(true, History.getLoginRedirectUrl())
                setStyleForAutoPopup()
                $('.close-auth-dialog-btn').one('click', setDefaultStyleForPopup)
        ,20000)

        setStyleForAutoPopup = ->
            # перекрываем стандартные стили поп-апа согласно макету, дополняем текст в шапку поп-апа
            $('head').append(StyleForChangedPopup())
            $('.auth-container div:first-child').hide()
            $('.auth-dialog').addClass('auto-popup').append(HeaderTextForAutoPopup).siblings('.notification-overlay').css({background:'#728AA0',opacity:'0.8'})

        setDefaultStyleForPopup = ->
            # при закрытии окошка, возвращаем все стили и тексты на место
            $('.auth-container div:first-child').show()
            $('.auth-dialog').removeClass('auto-popup')
            $('.call-to-action').remove()
            $('.auth-dialog').siblings('.notification-overlay').css({background:'#000000',opacity:'0.5'})

    _createAuthSplitTest: ->
        return if History.isEmbedded()
        authDlg = $('.js-auth-dialog')
        v1 = Math.round(Math.random()) is 1
        if v1
            _gaq.push(['_setCustomVar', 5, 'topic landing', '"sign in" slogan', 2])
        else
            _gaq.push(['_setCustomVar', 5, 'topic landing', '"Anonymous access" slogan', 2])
        renderSplit = window.CoffeeKup.compile(splitTmpl)
        authDlg.prepend(renderSplit({v1:v1}))

    _updateLoginCount: =>
        ec = localStorage.getEnterCount()
        ec = '0.0' if not ec
        ec = ec.split('.')
        ec = '0.0' if ec.length != 2
        ldate = ec[0]
        cnt = ec[1]
        curDate = Math.round(Date.now()/3600000/24)+''
        if ldate != curDate
            cnt++
            ldate = curDate
            localStorage.setEnterCount(ldate+'.'+cnt)
        if cnt == 5
            mixpanel.track("Visit 5 times", {"count":cnt})


    _trackNewVisit: =>
        # смотрим когда стартанула текущая сессия GA
        l = window.loggedIn
        return if not l
        gcookie = $.cookie('__utma')
        return if not gcookie
        gcookie = gcookie.split('.')
        return if gcookie.length<6

        # смотрим какую GA-сессию трекали в прошлый раз
        rcookie = localStorage.getLastAuth()
        if rcookie
            rcookie = rcookie.split('.')
            rcookie = ['',''] if rcookie.length < 2
        else
            rcookie = ['','']

        if gcookie[0] != rcookie[0] or gcookie[4] != rcookie[1]
            if window.justRegisteredForGA
                _gaq.push(['_trackEvent', 'Authorization', 'Visit started', 'visit started new'])
                mixpanel.track("Visit app", {"type":"new"})
                delete window.justRegisteredForGA
            else
                _gaq.push(['_trackEvent', 'Authorization', 'Visit started', 'visit started returning'])
                mixpanel.track("Visit app", {"type":"returning"})
            localStorage.setLastAuth(gcookie[0] + '.' + gcookie[4])


module.exports.trackTopicCreatedAndUserAdded = (usersAdded, topicCreated) ->
    users = localStorage.getUsersAdded()
    topics = localStorage.getTopicsCreated()
    if users*topics == 0 and (users+usersAdded)*(topics+topicCreated) > 0
        mixpanel.track("Create topic and add user", {})
module.exports.PingAnalytics = PingAnalytics
module.exports.instance = null