{Interactable, Event} = require('../../utils/interactable')
{BlipEventTypes} = require('./blip_events')

EDIT_MODE_EVENTS =
    CTRL_HANDLERS:
        13: BlipEventTypes.INSERT_INLINE_BLIP   # Enter
        53: BlipEventTypes.MAKE_BULLETED
        54: BlipEventTypes.MAKE_NUMBERED
        66: BlipEventTypes.MAKE_BOLD            # B
        73: BlipEventTypes.MAKE_ITALIC          # I
        76: BlipEventTypes.MANAGE_LINK          # L
        85: BlipEventTypes.MAKE_UNDERLINED      # U
        89: BlipEventTypes.REDO                 # Y
        90: BlipEventTypes.UNDO                 # Z
    CTRL_SHIFT_HANDLERS:
        90: BlipEventTypes.REDO                 # Y

READ_MODE_EVENTS =
    # null ставится, чтобы был preventDefault и браузер не менял DOM
    CTRL_HANDLERS:
        13: BlipEventTypes.INSERT_INLINE_BLIP  # Enter
        53: null
        54: null
        66: null    # B
        73: null    # I
        76: null    # L
        85: null    # U
        89: null    # Y
        90: null    # Z
    CTRL_SHIFT_HANDLERS:
        90: null    # Z

class KeyInteractor extends Interactable # TODO: it should be editor interactor
    constructor: (@_container) ->
        @_active = no

    _initKeyHandler: ->
        # TODO: move it to editor interactor
        ###
        Инициализирует обработчик нажатий на клавиши в блипе
        ###
        @_container.addEventListener('keydown', @_preProcessKeyDownEvent, true)

    _deinitKeyHandler: ->
        ###
        Снимает обработчик нажатий на клавиши в блипе
        ###
        @_container.removeEventListener('keydown', @_preProcessKeyDownEvent, true)

    _preProcessKeyDownEvent: (e) =>
        handlers = if e.shiftKey then @_ctrlShiftHandlers else @_ctrlHandlers
        @_processKeyDownEvent(handlers, e)

    _processKeyDownEvent: (handlers, e) =>
        ###
        Обрабатывает нажатия клавиш внутри блипов
        @param e: DOM event
        ###
        return console.warn('handler is not set') unless handlers
        return if (not (e.ctrlKey or e.metaKey)) or e.altKey
        return if not (e.keyCode of handlers)
        e.preventDefault()
        e.stopPropagation()
        @__dispatchEvent(handlers[e.keyCode]) if handlers[e.keyCode]?

    setEditModeKeyHandlers: ->
        # TODO: move it to editor interactor
        @_ctrlHandlers = EDIT_MODE_EVENTS.CTRL_HANDLERS
        @_ctrlShiftHandlers = EDIT_MODE_EVENTS.CTRL_SHIFT_HANDLERS

    setReadModeKeyHandlers: ->
        @_ctrlHandlers = READ_MODE_EVENTS.CTRL_HANDLERS
        @_ctrlShiftHandlers = READ_MODE_EVENTS.CTRL_SHIFT_HANDLERS

    attach: ->
        # listen events
        # TODO: remove it after editorInteractor
        @_initKeyHandler()

    detach: ->
        # stop listening events
        # TODO: remove it after editorInteractor
        @_deinitKeyHandler()

    destroy: ->
        @_deinitKeyHandler()
        delete @_container

module.exports = {KeyInteractor}