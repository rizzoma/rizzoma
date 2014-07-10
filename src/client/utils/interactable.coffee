MicroEvent = require('./microevent')

class Event
    constructor: (@type, @args) ->
        @_prevented = no

    preventDefault: ->
        @_prevented = yes

    isPrevented: -> @_prevented

class Interactable
    @EVENT = 'event'

    contructor: ->

    __dispatchEvent: (type, args = {}) ->
        @emit(Interactable.EVENT, new Event(type, args))

MicroEvent.mixin(Interactable)

module.exports = {Event, Interactable}
