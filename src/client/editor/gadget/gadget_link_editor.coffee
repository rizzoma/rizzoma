ck = window.CoffeeKup

gadgetLinkEditorTmpl = ->
    div '.link-editor-body', ->
        div style: 'font-size: 14px;', 'Insert link'
        table '.link-editor-content', ->
            tr '.link-url', ->
                td '', 'URL'
                td '', ->
                    label ->
                        input '.js-link-editor-url-input .text-input', {type: 'text'}
            tr '', ->
                td '', ''
                td '', ->
                    button '.js-link-editor-update-btn.button', title: 'Accept changes', 'Submit'

renderLinkEditor = ck.compile(gadgetLinkEditorTmpl)


DomUtils = require('../../utils/dom')
CenteredWindow = require('../../widget/window/centered_window').CenteredWindow
KeyCodes = require('../../utils/key_codes').KeyCodes

class GadgetLinkEditor extends CenteredWindow
    constructor: ->
        params =
            title: 'Insert gadget'
            closeButton: yes
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    __createDom: (params) ->
        super(params)
        tmp = document.createElement('span')
        $(tmp).append(renderLinkEditor())
        @_body.appendChild(tmp.firstChild)
        $c = $(@_body)
        @_$urlInput = $c.find('.js-link-editor-url-input').on('keypress', @_inputKeyPressHandler)
        $c.find('.js-link-editor-update-btn').bind 'click', @_update

    @get: -> @instance ?= new @

    _normalizeLink: (link) ->
        return 'http://' + link unless /^[a-zA-Z0-9\-]+:/.test(link)
        link

    _clear: ->
        @_$urlInput.val ''

    _update: =>
        ###
        Обработчик нажатия кнопки Update
        ###
        url = @_$urlInput.val()
        url = @_normalizeLink url
        @_editor.insertGadget(url)
        @close()

    _inputKeyPressHandler: (event) =>
        ###
        Обработчик клавиатурных событий keypress
        @param node: Event | KeyEvent
        ###
        if event.keyCode is KeyCodes.KEY_ENTER
            @_update()
            event.preventDefault()
            event.stopPropagation()

    close: ->
        super()
        if @_editor
            @_editor.resumeSetRange(yes, yes)
            delete @_editor

    open: (@_editor) ->
        ###
        Показывает окно редактирования url
        @param editor: Editor, объект, в котором редактируется ссылка
        @param range: DOM range, выделенный фрагмент
        ###
        @_clear()
        range = @_editor.getRange()
        if not range
            delete @_editor
            return
        super()
        @_editor.pauseSetRange(yes)
        @_$urlInput.select()

exports.get = -> GadgetLinkEditor.get()
