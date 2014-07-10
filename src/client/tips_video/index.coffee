ck = window.CoffeeKup

tipsVideoTmpl = ->
    div '.js-tips-video-overlay.tips-video-overlay', ''
    div '.js-tips-video-popup.tips-video-popup', ->
        div '.internal-container', ->
            div '.js-tips-video-close.tips-video-close', {title: 'Close'}, ''
            div '.tips-video-title', 'First Steps in Rizzoma'
            iframe ''
                , {
                    width: "640",
                    height: "480",
                    src: "https://www.youtube.com/embed/I7whBwsGzM8?fs=1&hl=en_En&color1=0x2b405b&color2=0x6b8ab6&autoplay=1&autohide=1&wmode=transparent",
                    frameborder:"0",
                    allowfullscreen: 'true'
                    webkitallowfullscreen: 'true'
                    mozallowfullscreen: 'true'
                  }

class TipsVideoPopup
    ###
    Попап с видео из панели подсказок
    ###

    constructor: (args...) ->
        @_init(args...)

    _init: () ->
        $(document.body).append(ck.render(tipsVideoTmpl))
        @_$popup = $('.js-tips-video-popup')
        @_setPosition()
        @_initCloseEvents()

    _setPosition: () ->
        popupWidth = @_$popup.width()
        left = (document.body.offsetWidth - popupWidth)/2
        @_$popup.css('left', left + 'px')

    _initCloseEvents: () ->
        @_$overlay = $('.js-tips-video-overlay')
        @_$closeControl = $('.js-tips-video-close')
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

exports.TipsVideoPopup = TipsVideoPopup