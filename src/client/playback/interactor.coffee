{Interactable} = require('../utils/interactable')
{EventProcessor} = require('./events')
{PopupContent, popup} = require('../popup')
{DateTimePicker} = require('../utils/date_time_picker')
{formatAsClientDate, formatAsClientTime, fromClientToDatetime} = require('../../share/utils/date_converter')
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
        @_blipMenu.disableReplaceButton() if not @_blipViewModel.getOriginalBlip()

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
        @_blipViewModel.getWave().forward()

    back: () ->
        @_blipViewModel.getWave().back()

    fastForward: () ->
        @_blipViewModel.getWave().fastForward()

    fastBack: () ->
        @_blipViewModel.getWave().fastBack()

    _onCalendarChange: (date) =>
        @_blipViewModel.getWave().playToDate(date)

    calendar: (target) ->
        return if popup.getContainer()
        calendarPopup = new CalendarPopup(@_currentCalendarDate or new Date(), @_onCalendarChange)
        popup.render(calendarPopup, target)
        popup.show()

    replace: () ->
        originalBlip = @_blipViewModel.getOriginalBlip()
        return if not originalBlip
        originalBlipView = originalBlip.getView()
        @_blipView.renderRecursively()
        opToInsert = @_blipView.getParent().getEditor().getCopyElementOp(@_blipView.getContainer())
        originalBlipView.getParent().getEditor().pasteBlipOpAfter(originalBlip.getContainer(), opToInsert)

    showOperationLoadingSpinner: () ->
        return if not @_blipMenu
        @_blipMenu.showOperationLoadingSpinner()

    hideOperationLoadingSpinner: () ->
        return if not @_blipMenu
        @_blipMenu.hideOperationLoadingSpinner()

    setCalendarDate: (date) ->
        return if not date
        @_currentCalendarDate = date
        return if not @_blipMenu
        @_blipMenu.setCalendarDate(date)

    setCalendarDateIfGreater: (date) ->
        return @setCalendarDate(date) if not @_currentCalendarDate
        return if @_currentCalendarDate > date
        @setCalendarDate(date)

    switchForwardButtonsState: (isDisable) ->
        return if not @_blipMenu
        @_blipMenu.switchForwardButtonsState(isDisable)

    switchBackButtonsState: (isDisable) ->
        return if not @_blipMenu
        @_blipMenu.switchBackButtonsState(isDisable)


renderCalendarPopup = ck.compile ->
    div '.playback-calendar-popup', ->
        dateParams = {type: 'text', tabindex: '1', value: @date}
        timeParams = {type: 'text', tabindex: '2', value: @time}
        div '', ->
            div '.date-icon.js-date-icon', ''
            input '.js-date-input', dateParams
        div '', ->
            div '.time-icon.js-time-icon', ''
            input '.js-time-input', timeParams


class CalendarPopup extends PopupContent
    constructor: (@_currentDate, @_onChange) ->
        @_dateTimePicker = new DateTimePicker()
        @_render()

    _render: () ->
        @_container = document.createElement('span')
        date = formatAsClientDate(@_currentDate)
        time = formatAsClientTime(@_currentDate)
        $(@_container).append(renderCalendarPopup({date, time}))
        $container = $(@_container)
        dateInput = $container.find('.js-date-input')[0]
        timeInput = $container.find('.js-time-input')[0]
        @_dateTimePicker.init(dateInput, timeInput)
        $container.find('.js-date-icon').click => $(dateInput).focus()
        $container.find('.js-time-icon').click => $(timeInput).focus()
        @_dateTimePicker.on 'change', (date, time) =>
            @_onChange(fromClientToDatetime(date, time))

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
