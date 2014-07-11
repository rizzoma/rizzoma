renderPopup = require('./template').renderPopup

class Popup
    ###
    Класс для работы с меню
    ###
    @POPUP_INDENT = 2
    
    render: (@_content, @_target) ->
        ###
        @content: PopupContent - экземпляр класса, который нужно отрисовать
        @_target: область, в которую кликнули
        Отрисовываем менюшку внутри контейнера попапа и навешиваем
        обработчики на события клика и изменения размеров окна
        ###
        $(document.body).append(renderPopup())
        @_container = $(document.body).find('.js-popup-menu-container')
        @_internalContainer = @_container.find('.js-internal-container > *')
        @_internalContainer.empty().append(@_content.getContainer())
        @_internalContainer.addClass(@_content.getInternalContainerClass)
        @setContainerPosition(@_getPosition())
        window.addEventListener 'click', @_windowClickHandler, true
        window.addEventListener 'resize', @_windowResize, false
        window.addEventListener 'scroll', @_scrollHandler, true
    
    _windowClickHandler: (event) =>
        return if not @_container
        if event.target == @_target
            @_destroy()
            event.stopPropagation()
            return
        return if $.contains(@_container[0], event.target)
        return if not @_content.shouldCloseWhenClicked(event.target)
        @_destroy()

    getContainer: ->
        return @_internalContainer

    getEventTarget: ->
        return @_target

    setContainerPosition: (pos) ->
        ###
        @pos: Object
        Устанавливаем позицию контейнеру менюшки
        ###
        @_lastPos = pos
        if pos.top?
            @_container.css('bottom', "auto")
            @_container.css('top', "#{pos.top}px")
        if pos.right?
            @_container.css('left', "auto")
            @_container.css('right', "#{pos.right}px")
        if pos.bottom?
            @_container.css('top', "auto")
            @_container.css('bottom', "#{pos.bottom}px")
        if pos.left?
            @_container.css('right', "auto")
            @_container.css('left', "#{pos.left}px")
    
    _remove: =>
        @_container.remove() if @_container
        delete @_container

    _destroy: =>
        ###
        Если клик мыши был за пределами контейнера, то
        удаляем ноду контейнера и отписываемся от событий клика и ресайза окна
        ###
        if @_content?
            @_content.destroy()
            delete @_content
        if @_internalContainer
            @_internalContainer.remove()
            delete @_internalContainer
        @_remove()
        window.removeEventListener 'click', @_windowClickHandler, true
        window.removeEventListener 'resize', @_windowResize, false
        window.removeEventListener 'scroll', @hide, true

    _windowResize: (event) =>
        @setContainerPosition(@_getPosition())

    _scrollHandler: =>
        return @hide() if not @_lastPos
        curPos = @_getPosition
        measures = ['top', 'right', 'bottom', 'left']
        for measure in measures
            return @hide if curPos[measure] isnt @_lastPos[measure]

    _getPosition: () ->
        ###
        Определяем как расположить контейнер в зависимости от координат
        элемента, на который кликнул пользователь
        ###
        offset = $(@_target).offset()
        centerX = $(window).width()/2
        centerY = $(window).height()/2
        pos = {}
        if offset.left <= centerX
            pos.left = offset.left + $(@_target).width()*0.2
        else
            pos.right = $(window).width() - offset.left - $(@_target).width()*(1 - 0.2)
        if offset.top <= centerY
            pos.top = offset.top + $(@_target).height() + Popup.POPUP_INDENT
        else
            pos.bottom = $(window).height()- offset.top + Popup.POPUP_INDENT
        return pos
    
    addExtendedClass: (addingClass) ->
        $(@_container).addClass(addingClass)

    show: -> @_container.show()
    
    hide: => 
        @_destroy()

    getContent: -> @_content
    
class PopupContent
    constructor: (args...) ->
        ###
        В конструкторе отрисовываем меню и, если нужно, вешаем обработчики
        ###
    
    destroy: ->
        ###
        В этом методе отписываемся от событий на которые были подписаны
        элементы меню, производим действия, необходимые при удалении объекта меню
        Метод необходимо переопределять в наследнике даже если он там неиспользуется
        ###
        throw new Error("Menu method 'destroy' not implemented")
    
    getContainer: ->
        ###
        В этом методе возвращается коренвая нода
        ###
        throw new Error("Menu method 'getContainer' not implemented")

    shouldCloseWhenClicked: (element) ->
        ###
        Возвращает true, если при клике на указанный элемент нужно закрыть попап
        @param element: HTMLNode
        @return: boolean
        ###
        return true

    getInternalContainerClass: ->
        'internal-container'

exports.popup = new Popup()
exports.PopupContent = PopupContent