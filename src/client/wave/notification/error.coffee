renderError = require('./template').renderError
WaveNotification = require('./notification').WaveNotification
History = require('../../utils/history_navigation')

class WaveError extends WaveNotification
    ###
    Класс, представляющий ошибку волны
    ###
    
    constructor: (@_error) ->
        ###
        @param _error: object, объект ошибки
        ###
        super()    
        @_container.addClass("wave-error")
        @_container.addClass("js-wave-error")
        @_createDOM()
        if @_closeButton
            $(@_closeButton).bind 'click', @_hideError

    _createDOM: ->
        ###
        Создает DOM для показа ошибки
        ###
        if window.loggedIn
            @_container.append renderError(error: @_error)
            @_closeButton = @_container.find('.js-error-close-button')[0]
        else
            window.AuthDialog.initAndShow(false, History.getLoginRedirectUrl())

module.exports.WaveError = WaveError