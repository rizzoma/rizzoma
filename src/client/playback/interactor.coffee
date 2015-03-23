{Interactable} = require('../utils/interactable')
{EventProcessor} = require('./events')
{PopupContent, popup} = require('../popup')
{DateTimePicker} = require('../utils/date_time_picker')
ck = window.CoffeeKup


class PlaybackInteractor
    constructor: (@_blipViewModel, @_blipView) ->  # TODO: we definitely need only one of them
        @_interactables = []

    _handleEvent: (event) =>
        if not EventProcessor[event.type]?
            console.trace?()
            return console.warn("Event '#{event.type}' is not supported")
        try
            EventProcessor[event.type](@, event.args)
        catch e
            console.error('Failed to handle event', e)

    _attach: (interactable) ->
        return if @_interactables.indexOf(interactable) >= 0
        interactable.on(Interactable.EVENT, @_handleEvent)
        @_interactables.push(interactable)

    _detach: (interactable) ->
        return if (index = @_interactables.indexOf(interactable)) < 0
        @_interactables[index].removeListener(Interactable.EVENT, @_handleEvent)
        @_interactables.splice(index, 1)

    _attachMenu: (blipMenu, placeHolder, params) ->
        return if @_blipMenu
        #@_keyInteractor.attach() # TODO: do not detach when keyInteractor -> editorInteractor
        placeHolder.appendChild(blipMenu.getContainer())
        blipMenu.reset(params)
        @_attach(blipMenu)
        @_blipMenu = blipMenu
        #@_updateEditingModifiers()
        #@_updateUndoRedoState()

    _detachMenu: ->
        #@_keyInteractor.detach() # TODO: do not detach when keyInteractor -> editorInteractor
        return unless @_blipMenu
        menuElement = @_blipMenu.getContainer()
        menuElement.parentNode?.removeChild(menuElement)
        @_detach(@_blipMenu)
        #todo: see blip_menu:detach()
        #@_blipMenu?.detach()
        delete @_blipMenu

    setCanEdit: () ->

    setEditableMode: () ->

    setFoldable: () ->

    updateEditingModifiers: () ->

    enableIdDependantButtons: () ->

    setSendable: () ->

    getBlip: -> @_blipView

    attachMenu: (blipMenu, placeHolder, params) -> @_attachMenu(blipMenu, placeHolder, params)

    detachMenu: -> @_detachMenu()

    attach: (interactable) -> @_attach(interactable)

    detach: (interactable) -> @_detach(interactable)

    destroy: ->
        @_detachMenu()
        delete @_blipViewModel
        delete @_blipView
        delete @_blipMenu
        for interactable in @_interactables
            interactable.removeListener(Interactable.EVENT, @_handleEvent)
        delete @_interactables

    copy: () ->
        @_blipView.renderRecursively()
        @_blipView.getParent().getEditor().copyElementToBuffer(@_blipView.getContainer())

    forward: () ->
        @_blipViewModel.forward()

    back: () ->
        @_blipViewModel.back()

    calendar: (target) ->
        return if popup.getContainer()
        calendarPopup = new CalendarPopup()
        popup.render(calendarPopup, target)
        popup.show()

    replace: () ->
        originalBlip = @_blipViewModel.getOriginalBlip()
        return if not originalBlip
        originalBlipView = originalBlip.getView()
        @_blipView.renderRecursively()
        opToInsert = @_blipView.getParent().getEditor().getCopyElementOp(@_blipView.getContainer())
        originalBlipView.getParent().getEditor().pasteBlipOpAfter(originalBlip.getContainer(), opToInsert)



renderCalendarPopup = ck.compile ->
    div '.playback-calendar-popup', ->
        date = '13.03.2015'
        time = '12:15'
        dateParams = {type: 'text', tabindex: '1', value: date}
        timeParams = {type: 'text', tabindex: '2', value: time}
        div '.date-icon.js-date-icon', ''
        input '.js-date-input', dateParams
        div '.time-icon.js-time-icon', ''
        input '.js-time-input', timeParams


class CalendarPopup extends PopupContent
    constructor: () ->
        @_dateTimePicker = new DateTimePicker()
        @_render()

    _render: () ->
        @_container = document.createElement('span')
        $(@_container).append(renderCalendarPopup({}))
        $container = $(@_container)
        dateInput = $container.find('.js-date-input')[0]
        timeInput = $container.find('.js-time-input')[0]
        @_dateTimePicker.init(dateInput, timeInput)
        $container.find('.js-date-icon').click => $(dateInput).focus()
        $container.find('.js-time-icon').click => $(timeInput).focus()
        @_dateTimePicker.on 'change', (date, time) =>
            console.log date, time

    destroy: ->
        @_dateTimePicker?.destroy()
        delete @_dateTimePicker
        $(@_container).remove()
        delete @_container

    getContainer: ->
        @_render() if not @_container
        return @_container

    shouldCloseWhenClicked: (element) ->
        return true


module.exports = {PlaybackInteractor}
