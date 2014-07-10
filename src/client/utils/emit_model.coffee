MicroEvent = require('./microevent')

class EmitModel
    @PROPS: [] # list of props allowed to set using __setProperty

    __setProperty: (eventName, prop, value) ->
        if @constructor.PROPS.indexOf(prop) < 0
            throw new Error("Property #{prop} doesn't belong to allowed prop list")
        return if value is @[prop]
        @emit(eventName, value, @[prop])
        @[prop] = value

    destroy: ->
        @removeAllListeners()

MicroEvent.mixin(EmitModel)

module.exports = EmitModel
