CenteredWindow = require('../../widget/window/centered_window').CenteredWindow
WarnWindow = require('../../widget/window/warning')
KeyCodes = require('../../utils/key_codes').KeyCodes
renderLinkEditor = require('./template').renderLinkEditor
{MAX_URL_LENGTH} = require('../common')

Action =
    MARK_LINK: 'markLink'
    INSERT_TEXT: 'insertText'

class LinkEditor extends CenteredWindow
    constructor: ->
        params =
            title: 'Insert link'
            closeButton: yes
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    close: ->
        super()
        @_$textInput.hide()
        @_$textDiv.hide()
        delete @_updateLink
        delete @_insertText

    open: (text, url, editable, @_updateLink, @_insertText) ->
        @_clear()
        super()
        @_initialText = text || ''
        @_setText(@_initialText)
        @_setUrl(url || '')
        if editable
            @_$textInput.show()
            @_action = Action.INSERT_TEXT
            if @_initialText then @_$urlInput.select() else @_$textInput.select()
            return
        @_action = Action.MARK_LINK
        @_$textDiv.show()
        @_$urlInput.select()

    __createDom: (params) ->
        super(params)
        tmp = document.createElement('span')
        $(tmp).append(renderLinkEditor())
        @_body.appendChild(tmp.firstChild)
        $c = $(@_body)
        @_$textInput = $c.find('.js-link-editor-text-input').on('keypress', @_inputKeyPressHandler)
        @_$textDiv = $c.find('.js-link-editor-text-div')
        @_$urlInput = $c.find('.js-link-editor-url-input').on('keypress', @_inputKeyPressHandler)
        $c.find('.js-link-editor-update-btn').on('click', @_update)
        $c.find('.js-link-editor-remove-btn').on('click', @_remove)

    @get: -> @instance ?= new @

    _normalizeLink: (link) ->
        link = link.replace(/^\s+|\s+$/g, '')
        return 'http://' + link if /^(javascript|vbscript):/.test(link)
        return 'http://' + link unless /^([a-zA-Z0-9\-]+):/.test(link)
        link

    _clear: ->
        @_$textInput.val ''
        @_$urlInput.val ''

    _update: =>
        ###
        Обработчик нажатия кнопки Update
        ###
        url = @_$urlInput.val()
        return @_remove() if not url
        url = @_normalizeLink url
        if url.length > MAX_URL_LENGTH
            return new WarnWindow('Your URL is too long')
        if @_action is Action.MARK_LINK
            @_updateLink(url)
        else
            text = @_$textInput.val()
            return @_$textInput.focus() if not text
            if @_initialText is text
                @_updateLink(url)
            else
                @_insertText(text, url)
        @close()

    _remove: =>
        ###
        Обработчик нажатия кнопки Remove
        ###
        @_updateLink(null)
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

    _setText: (text) ->
        @_$textInput.val text
        @_$textDiv.text text

    _setUrl: (url) ->
        @_$urlInput.val url

instance = null
exports.LinkEditor =
    get: ->
        instance ?= new LinkEditor()

