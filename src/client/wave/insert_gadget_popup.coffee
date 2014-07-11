renderGadgetPopup = require('../popup/template').renderGadgetPopup
ck = window.CoffeeKup

renderInsertGadget = ck.compile ->
    if @gadget.cssClass?
        classString = @gadget.cssClass
        style = ''
    else
        classString = "js-#{h(@gadget.id)}.#{h(@gadget.id)}"
        style = "background: url(#{h(@gadget.icon)}) 0 0 no-repeat;"

    button ".js-gadget-button.gadget-icon.#{classString}", {
        gadgetUrl: h(@gadget.url)
        title: h(@gadget.title)
        trackId: h(@gadget.title)
        style: style
    }

renderGadgetStub = ck.compile ->
    button ".js-gadget-stub.gadget-stub", 'Add gadget'

class InsertGadgetPopup

    GADGETS_IN_ROW = 8

    constructor: (@_$container, @_$button) ->
        $(@_$container).append(renderGadgetPopup())
        @_$popup = @_$container.find('.js-gadget-popup-menu-container')
        @_$popup.on 'mousedown', (e) ->
            e.stopPropagation()
            e.preventDefault()
        @_$internalContainer = @_$container.find('.js-internal-container > *')
        @_$internalContainer.addClass('internal-container')
        @_$internalContainer.append(renderGadgetStub())
        @_gadgetsIndex = 1
        @_$popup.on 'click', '.js-gadget-button', (e) =>
            button = $(e.currentTarget)
            @_activeBlip.insertGadget(button.attr('gadgetUrl'))
            gadgetClass = button.attr('trackid')
            _gaq.push(['_trackEvent', 'Store', 'Insert gadget', gadgetClass])
            @hide()
        $gadgetStub = @_$popup.find('.js-gadget-stub')
        $gadgetStub.on 'click', (e) =>
            _gaq.push(['_trackEvent', 'Store', 'Add gadget click'])
            require('../navigation').instance.showMarketPanel()

    _initGadgets: ->
        return if @_gadgetsInited
        @_gadgetsInited = true
        installedGadgets = require('../market_panel').instance.getInstalledGadgets()
        for gadget in installedGadgets
            @_addGadget(gadget)

    _addGadget: (gadget) ->
        @_$internalContainer.append(renderInsertGadget({gadget}))
        @_gadgetsIndex += 1
        if @_gadgetsIndex % GADGETS_IN_ROW is 0
            @_$internalContainer.append("<br>")

    getContainer: -> @_container

    show: (@_activeBlip) ->
        # Инициализацию проводим при первом показе, чтобы у гаджетов было как можно больше времени на загрузку с сервера
        @_initGadgets()
        window.setTimeout =>
            $(document).on 'mousedown.selectGadgetBlock', (e) =>
                return if $(e.target).closest('.js-gadget-popup-menu-container').length != 0
                @hide()
        , 0
        @_$button.addClass('active')
        @_$popup.show()

    hide: ->
        $(document).off 'mousedown.selectGadgetBlock'
        @_$button.removeClass('active')
        @_$popup.hide()

    addGadget: (gadget) ->
        @_addGadget(gadget)

    removeGadget: (gadget) ->
        if @_gadgetsIndex % GADGETS_IN_ROW is 0
            @_$internalContainer.find("br:last").remove()
        gadgetSelector = ".js-#{gadget.id}"
        @_$internalContainer.find(gadgetSelector).remove()
        @_gadgetsIndex -= 1

    isVisible: ->
        @_$popup.is(':visible')

    destroy: ->
        @hide()
        @_$container.find('.js-gadget-popup-menu-container').remove()

module.exports = {InsertGadgetPopup}