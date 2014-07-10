DomUtils = require('../utils/dom')
SelectionHelper = require('./selection/html_selection_helper')

BUFFER_CHECK_INTERVAL = 50
DEADLINE_TIMEOUT = 250

class Buffer
    constructor: ->
        @_container = document.createElement('div')
        @_container.contentEditable = 'false'
        @_container.style.display = 'inline-block'
        @_dataContainer = @_container.appendChild(document.createElement('div'))
        @_dataContainer.style.display = 'inline-block'
        @_dataContainer.style.border = '1px solid transparent'
        @_dataContainer.style.margin = '-1px'
        @_dataContainer.style.whiteSpace = 'pre-wrap'
        @_dataContainer.style.zIndex = 200
        @_dataContainer.style.backgroundColor = 'white'
        @_dataContainer.style.outline = 'none'
        @_dataContainer.contentEditable = 'true'
        @_changeIntervalId = null
        @_deadLineTimeoutId = null
        $(document).ready =>
            @detach()

    _clear: ->
        @_dataContainer.removeChild(@_dataContainer.firstChild) while @_dataContainer.firstChild

    _checkBuffer: =>
        return if @_dataContainer.firstChild is @_currentFirstChild and @_dataContainer.textContent is @_currentText
        fragment = document.createDocumentFragment()
        while @_dataContainer.firstChild
            fragment.appendChild(@_dataContainer.firstChild)
        @_notifyChanged(null, fragment)

    _notifyChanged: (error, data = null) =>
        @_changeIntervalId = clearInterval(@_changeIntervalId) if @_changeIntervalId?
        @_deadLineTimeoutId = clearTimeout(@_deadLineTimeoutId) if @_deadLineTimeoutId?
        if @_textChangeCallback
            @_textChangeCallback(error, data)
        @_removeTextChangeListener()
        @_clear()

    _removeTextChangeListener: ->
        @_changeIntervalId = clearInterval(@_changeIntervalId) if @_changeIntervalId?
        @_deadLineTimeoutId = clearTimeout(@_deadLineTimeoutId) if @_deadLineTimeoutId?
        delete @_textChangeCallback if @_textChangeCallback
        delete @_currentText if @_currentText?

    _focus: -> @_dataContainer.focus()

    focus: -> @_focus()

    clear: -> @_clear()

    selectAll: ->
        SelectionHelper.selectNodeContents(@_dataContainer)
        @_focus()

    getText: ->
        @_dataContainer.textContent

    setFragmentContent: (fragment) ->
        @_clear()
        @_dataContainer.appendChild(fragment) if fragment

    attachNextTo: (nextTo) ->
        @_container.style.position = 'static'
        return unless DomUtils.insertNextTo(@_container, nextTo)
        @_attached = yes
        @_clear()
        SelectionHelper.setCaret(@_dataContainer, 0)

    onTextChange: (@_textChangeCallback) ->
        clearInterval(@_changeIntervalId) if @_changeIntervalId?
        clearTimeout(@_deadLineTimeoutId) if @_deadLineTimeoutId?
        @_currentText = @_dataContainer.textContent
        @_currentFirstChild = @_dataContainer.firstChild
        @_changeIntervalId = setInterval(@_checkBuffer, BUFFER_CHECK_INTERVAL)
        @_deadLineTimeoutId = setTimeout =>
            @_notifyChanged(yes)
        , DEADLINE_TIMEOUT

    detach: ->
        return if @_attached is no
        @_attached = no
        @_container.style.position = 'absolute'
        @_container.style.top = '-9999px'
        @_container.style.left = '-9999px'
        document.body.appendChild(@_container)
        @_clear()

    isAttached: ->
        @_attached

exports.Buffer = new Buffer()