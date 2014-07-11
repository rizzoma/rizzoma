ck = window.CoffeeKup
{KeyCodes} = require('../utils/key_codes')

mergeSuccessfulPopupTmpl = ->
    div ->
        div '.js-notification-overlay.notification-overlay.successful-merge', ''
        div '.notification-block', ->
            div '.js-account-merge-form-container.account-merge-form-container.successful-merge', ->
                div '.js-merge-close.merge-close', {title: 'Close'}, ''
                div '.merge-title', ->
                    img '.ok-image', {src: '/s/img/contacts-refreshed.png'}
                    text 'Merging of accounts was successfully complete. Please reload all browser tabs with Rizzoma.com.'
                button '.js-merge-close.button', 'Close'
renderPopup = ck.compile(mergeSuccessfulPopupTmpl)


class SuccessfulMergePopup
    show: ->
        @_$container = $(renderPopup({email: @_email}))
        $(document.body).append(@_$container)
        @_initClose()

    _initClose: ->
        @_$container.find('.js-notification-overlay, .js-merge-close').click(@_close)
        $(window).keydown(@_windowKeyHandler)

    _windowKeyHandler: (e) =>
        @_close() if e.which is KeyCodes.KEY_ESCAPE

    _close: =>
        $(window).off('keydown', @_windowKeyHandler)
        @_$container.remove()

module.exports = {SuccessfulMergePopup}