MicroEvent = require('../utils/microevent')
getOpenSocial = require('../wave/opensocial').get
ck = window.CoffeeKup

render = ck.compile ->
    div '.gadget-outer-container', contentEditable: 'false', ->
        div '.gadget-error-message', ->
            text "Can't load gadget"
            button 'Try again'
        div '.gadget-container', ''

class Gadget
    constructor: (url, state, editMode) ->
        @_createContainer()
        getOpenSocial()?.loadGadget(url, state, editMode, @)

    destroy: ->
        getOpenSocial()?.unloadGadget(@)

    _createContainer: ->
        container = $(render())
        container.find('.gadget-error-message button').click =>
            container.removeClass('gadget-error').addClass('gadget-loading')
            getOpenSocial()?.reloadGadget(@)
        container.addClass('gadget-loading')
        @_container = container[0]

    onLoad: ->
        $(@_container).removeClass('gadget-loading gadget-error')

    onError: ->
        $(@_container).removeClass('gadget-loading').addClass('gadget-error')

    getContainer: ->
        @_container

    getGadgetContainer: ->
        return $(@_container).find('.gadget-container')[0]

    setStateDelta: (delta) ->
        getOpenSocial()?.setStateDelta(@, delta)

    setMode: (editMode) ->
        getOpenSocial()?.setMode(@, editMode)

Gadget = MicroEvent.mixin(Gadget)
exports.Gadget = Gadget
