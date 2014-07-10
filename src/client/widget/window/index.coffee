renderBaseWindow = require('./template').renderBaseWindow
MicroEvent = require('../../utils/microevent')

class Window
    ###
    Базовый класс
    @params {Object} params:
        title: string
        closeButton: bool
        closeOnOutsideAction: bool - закрывает окно при событиях mousedown, keydown вне окна
        closeOnEsc: bool
        onClose: Function - Если возвращает false, то окно не будет закрыто
    ###
    constructor: (params = {}) ->
        @__createDom(params)
        @_closeOnOutsideAction = params['closeOnOutsideAction'] || no
        @_destroyOnClose = params['destroyOnClose'] || no

    __createDom: (params) ->
        wndParams =
            title: params['title'] || ''
            closeButton: params['closeButton'] || no
        tmpEl = document.createElement('span')
        $(tmpEl).append renderBaseWindow(wndParams)
        @_wnd = tmpEl.firstChild
        $wnd = $(@_wnd)
        @_body = $wnd.find('.js-window-body')[0]
        if params['closeButton']
            $wnd.find('.js-window-close-btn').bind('click', => @close())
        if params['closeOnEsc']
            $wnd.bind('keydown', @_keyHandler)
        if $.isFunction(params['onClose'])
            @_onClose = params['onClose']

    __addGlobalListeners: ->
        window.addEventListener('mousedown', @__handleOutsideEvent, yes)
        window.addEventListener('keydown', @__handleOutsideEvent, yes)

    __removeGlobalListeners: ->
        window.removeEventListener('mousedown', @__handleOutsideEvent, yes)
        window.removeEventListener('keydown', @__handleOutsideEvent, yes)

    _keyHandler: (event) =>
        ###
        Обработчик клавиатурных событий keypress, keydown
        @param node: Event | KeyEvent
        ###
        if event.keyCode is 27
            @close()
            event.preventDefault()
            event.stopPropagation()

    __handleOutsideEvent: (event) =>
        @close() if not $.contains(@_wnd, event.target)

    setContent: (content) ->
        $(@_body).empty().append(content)

    destroy: ->
        delete @_destroyOnClose
        @close(yes)
        $(@_wnd).remove()
        delete @_wnd
        delete @_onClose

    getWindow: ->
        @_wnd

    getBodyEl: ->
        @_body

    setWidth: (width) ->
        ###
        @param width: int
        ###
        $(@_wnd).css('width', width)

    open: ->
        @__addGlobalListeners() if @_closeOnOutsideAction
        $(@_wnd).show()

    close: (force = no) =>
        @__removeGlobalListeners() if @_closeOnOutsideAction
        try @emit('close')
        @removeAllListeners('close')
        return if not force and @_onClose and not @_onClose()
        $(@_wnd).hide()
        @destroy() if @_destroyOnClose
        yes

MicroEvent.mixin(Window)
exports.Window = Window
