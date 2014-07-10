class WaveNotification
    ###
    Класс, представляющий любое уведомление волны
    ###
    constructor: ->
        @_container = document.createElement('div')
        @_container = $(@_container)
        
    _hideError: =>
        ###
        Прячет показываемую ошибку
        ###
        @_container.remove()
        $(window).trigger 'resize'
        
    getContainer: =>
        @_container

module.exports.WaveNotification = WaveNotification