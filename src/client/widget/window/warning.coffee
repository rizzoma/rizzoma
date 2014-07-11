ModalWindow = require('./modal_window').ModalWindow
DomUtils = require('../../utils/dom')
KeyCodes = require('../../utils/key_codes').KeyCodes

contentTmpl = ->
    h1 "#{@msg}"
    div 'centered', ->
        button 'js-ok-button button', 'Ok'
renderContent = window.CoffeeKup.compile(contentTmpl)

class WarningWindow extends ModalWindow
    constructor: (msg, title = '') ->
        params =
            title: title || 'Warning'
            closeButton: yes
            closeOnEsc: yes
            destroyOnClose: yes
            msg: msg
        super(params)
        @open()

    __createDom: (params) ->
        super(params)
        p = {msg: params.msg}
        content = DomUtils.parseFromString(renderContent(p))
        @setContent(content)
        wnd = @getWindow()
        DomUtils.addClass(wnd, 'warning-window')
        btn = wnd.getElementsByClassName('js-ok-button')[0]
        btn.addEventListener('click', @close, no)
        btn.addEventListener 'keydown', (e) ->
            e.preventDefault() if e.keyCode is KeyCodes.KEY_TAB
        , no
        @getContainer().addEventListener 'mousedown', (e) ->
            e.preventDefault()
            @getElementsByClassName('js-ok-button')[0]?.focus()
        , no

    open: (args...) ->
        super(args...)
        @getWindow().getElementsByClassName('js-ok-button')[0]?.focus()

    destroy: (args...) ->
        @getWindow().getElementsByClassName('js-ok-button')[0].removeEventListener('click', @close, no)
        super(args...)

module.exports = WarningWindow
