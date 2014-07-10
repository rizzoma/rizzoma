renderCrowdPopup = require('./template').renderCrowdPopup
{LocalStorage} = require('../utils/localStorage')

SHOW_CROWD_POPUP = 'scp'

class CrowdPopup

    constructor: (args...) ->
        @_init(args...)

    _init: (setCookie=false) ->
        if setCookie
            $.cookie(SHOW_CROWD_POPUP, 1, {path: '/topic/', expires: 100})
        $(document.body).append(renderCrowdPopup({scpCookie: parseInt($.cookie(SHOW_CROWD_POPUP)) is 1}))
        @_$popup = $('.js-crowd-popup')
        @_$checkbox = @_$popup.find('#js-show-crowd-popup')
        @_$checkbox.on 'change', (e) ->
            if $(e.currentTarget).is(':checked')
                $.cookie(SHOW_CROWD_POPUP, 1, {path: '/topic/', expires: 100})
            else
                $.cookie(SHOW_CROWD_POPUP, 0, {path: '/topic/', expires: 100})
        @_setPosition()
        @_initCloseEvents()

    _setPosition: ->
        popupWidth = @_$popup.width()
        left = (document.body.offsetWidth - popupWidth)/2
        @_$popup.css('left', left + 'px')

    _initCloseEvents: ->
        @_$overlay = $('.js-crowd-overlay')
        @_$closeControl = $('.js-crowd-close')
        @_$overlay.on 'click', @_close
        @_$closeControl.on 'click', @_close
        $(window).on 'keydown', @_windowKeyHandler

    _windowKeyHandler: (e) =>
        return if e.which != 27
        @_close()

    _close: =>
        if @_$checkbox.is(':checked')
            _gaq.push(['_trackEvent', 'Crowd popup', 'close', 'with show later'])
        else
            _gaq.push(['_trackEvent', 'Crowd popup', 'close', 'forever'])
        $(window).off 'keydown', @_windowKeyHandler
        @_$popup.remove()
        @_$overlay.remove()


CrowdPopup.canShowPopup = ->
    if window.firstSessionLoggedIn
        # условия для нового пользователя (window.userInfo.daysAfterFirstVisit < 22)
        # пока совсем новым (тем у кого меньше 6и визитов) пользователям не показываем
#        if LocalStorage.getLoginCount() is 6
#            return true
        if LocalStorage.getLoginCount() > 6
            if $.cookie(SHOW_CROWD_POPUP) and parseInt($.cookie(SHOW_CROWD_POPUP)) is 1
                return true
            if not $.cookie(SHOW_CROWD_POPUP)
                return true
        #условия для старого пользователя (window.userInfo.daysAfterFirstVisit >= 22)
        if window.userInfo.daysAfterFirstVisit >= 22
            if $.cookie(SHOW_CROWD_POPUP) and parseInt($.cookie(SHOW_CROWD_POPUP)) is 1
                return true
            if not $.cookie(SHOW_CROWD_POPUP)
                return true

exports.CrowdPopup = CrowdPopup
