renderWarning = require('./template').renderWarning
WaveNotification = require('./notification').WaveNotification

class WaveWarning extends WaveNotification
    ###
    Класс, представляющий предупреждение волны
    ###
    
    constructor: (@_message) ->
        ###
        @param _message: String, сообщение
        ###
        super()    
        @_container.addClass("wave-warning")
        @_container.addClass("js-wave-warning")
        @_createDOM()
        if @_closeButton
            $(@_closeButton).bind 'click', @_hideError
        setTimeout(@_hideError, 5000)
    
    _createDOM: ->
        ###
        Создает DOM для показа предупреждения
        ###
        @_container.append renderWarning(message: @_message)
        @_closeButton = @_container.find('.js-warning-close-button')[0]

module.exports.WaveWarning = WaveWarning