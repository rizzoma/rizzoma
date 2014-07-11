MicroEvent = require('../utils/microevent')
BE = require('../utils/browser_events')
{KeyCodes} = require('../utils/key_codes')

class EventInteractor
    __dispatchInsertInlineBlipEvent: ->
        try @emit('blip')

    destroy: ->
        @removeAllListeners()

MicroEvent.mixin(EventInteractor)

class KeyEventInteractor extends EventInteractor
    constructor: (@_root) ->
        @_bindEvents()

    _bindEvents: ->
        @_root.addEventListener(BE.KEY_DOWN_EVENT, @_handleKeyDownEvent, yes)

    _unbindEvents: ->
        @_root.removeEventListener(BE.KEY_DOWN_EVENT, @_handleKeyDownEvent, yes)

    _handleKeyDownEvent: (e) =>
        return if e.shiftKey or e.altKey
        return unless e.ctrlKey or e.metaKey
        if e.keyCode is KeyCodes.KEY_ENTER
            @__dispatchInsertInlineBlipEvent()
            BE.blockEvent(e)

    destroy: ->
        super()
        @_unbindEvents()
        delete @_root

module.exports = {KeyEventInteractor}
