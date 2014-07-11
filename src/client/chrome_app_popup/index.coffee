renderChromeAppPopup = require('./template').renderChromeAppPopup
social = require('../utils/social')

class ChromeAppPopup

    constructor: (args...) ->
        @_init(args...)

    _init: () ->
        social.addFacebookScript()
        $(document.body).append(renderChromeAppPopup())
        @_$popup = $('.js-chrome-app-popup')
        @_setPosition()
        @_initCloseEvents()
        _subscribe = ->
            FB.Event.subscribe 'edge.create', (targetUrl) ->
                _gaq.push(['_trackSocial', 'facebook', 'Like', targetUrl, 'Chrome app popup']);
                _gaq.push(['_trackEvent', 'Social', 'Like', 'Chrome app popup']);

        if FB?
            _subscribe()
        else
            if window.fbAsyncInit
                prevAI = window.fbAsyncInit
                window.fbAsyncInit = ->
                    prevAI()
                    _subscribe()
            else
                window.fbAsyncInit = ->
                    _subscribe()

    _setPosition: () ->
        popupWidth = @_$popup.width()
        left = (document.body.offsetWidth - popupWidth)/2
        @_$popup.css('left', left + 'px')

    _initCloseEvents: () ->
        @_$overlay = $('.js-cap-overlay')
        @_$closeControl = $('.js-cap-close')
        @_$overlay.on 'click', @_close
        @_$closeControl.on 'click', @_close
        $(window).on 'keydown', @_windowKeyHandler

    _windowKeyHandler: (e) =>
        return if e.which != 27
        @_close()

    _close: =>
        $(window).off 'keydown', @_windowKeyHandler
        @_$popup.remove()
        @_$overlay.remove()

exports.ChromeAppPopup = ChromeAppPopup
