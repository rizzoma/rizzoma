MicroEvent = require('../utils/microevent')

class WaveView
    @Events:
        READ_ALL: 'readAll'

    __activateBlip: (blip) ->
        # TODO: implement it here
        @markActiveBlip(blip.getView())
    markActiveBlip: ->

    __scrollToBlipContainer: (blipContainer) ->

    activateBlip: (blip) ->
        blip.unfoldToRoot()
        @__activateBlip(blip)
        @__scrollToBlipContainer(blip.getContainer())

    showGrantAccessForm: (title, user, role, add) ->
        wnd = new (require('./grant_access_window'))
        wnd.open(title, user, role, add)

    destroy: ->
        @removeAllListeners()

MicroEvent.mixin(WaveView)

module.exports = WaveView
