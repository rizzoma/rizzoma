{renderBlipMenu} = require('./template')
BrowserEvents = require('../utils/browser_events')
DomUtils = require('../utils/dom')
{Interactable} = require('../utils/interactable')
{PlaybackEventTypes} = require('./events')
{formatAsShortenedDateTime} = require('../../share/utils/datetime')

BUTTONS_ORDER = []

BUTTON_PARAMS =
    CalendarButton:
        selectionClass: 'js-calendar-button'
        event: PlaybackEventTypes.CALENDAR
    FastBackButton:
        selectionClass: 'js-fast-back-button'
        event: PlaybackEventTypes.FAST_BACK
    BackButton:
        selectionClass: 'js-back-button'
        event: PlaybackEventTypes.BACK
    ForwardButton:
        selectionClass: 'js-forward-button'
        event: PlaybackEventTypes.FORWARD
    FastForwardButton:
        selectionClass: 'js-fast-forward-button'
        event: PlaybackEventTypes.FAST_FORWARD
    CopyButton:
        selectionClass: 'js-copy-button'
        event: PlaybackEventTypes.COPY
    ReplaceButton:
        selectionClass: 'js-replace-button'
        event: PlaybackEventTypes.REPLACE

# Дополнительная ширина меню, создаваемая всплывающим меню при нажатии на шестеренку
OVERFLOW_MENU_ADDITIONAL_WIDTH = 60
ADDITIONAL_MENU_WIDTH = 15 # adding space for changing Hide to Hidden
TOTAL_WIDTH = null

getMenuDom = ->
    tmpEl = document.createElement('span')
    tmpEl.className = 'blip-menu'
    tmpEl.appendChild(DomUtils.parseFromString(renderBlipMenu({})))
    return tmpEl

getTotalWidth = ->
    tmpEl = getMenuDom()
    document.body.appendChild(tmpEl)
    editBlock = tmpEl.getElementsByClassName('js-playback-menu')[0]
    buttons = editBlock.children
    total = 0
    for b in buttons
        total += b.offsetWidth
    document.body.removeChild(tmpEl)
    total + ADDITIONAL_MENU_WIDTH

getEditBlockTotalWidth = ->
    return TOTAL_WIDTH if TOTAL_WIDTH
    return 1 unless DomUtils.isCssReady()
    TOTAL_WIDTH = getTotalWidth()

class PlaybackBlipMenu extends Interactable
    constructor: ->
        super()
        @_hiddenEditButtons = []
        @_container = getMenuDom()
        @_$container = $(@_container)
        @_$calendarButton = @_$container.find('.js-calendar-button')
        @_$fastBackButton = @_$container.find('.js-fast-back-button')
        @_$backButton = @_$container.find('.js-back-button')
        @_$forwardButton = @_$container.find('.js-forward-button')
        @_$fastForwardButton = @_$container.find('.js-fast-forward-button')
        @_initButtons()
        BrowserEvents.addBlocker(@_container, BrowserEvents.MOUSE_DOWN_EVENT)
        BrowserEvents.addBlocker(@_container, BrowserEvents.MOUSE_UP_EVENT)
        BrowserEvents.addBlocker(@_container, BrowserEvents.CLICK_EVENT)

    _initButtons: ->
        @_$container.on('click', "button", @_handleButtonClick)

    _getButtonBySelectionClass: (button) ->
        return props if (key = button.rzParamName) and (props = BUTTON_PARAMS[key])
        for key, props of BUTTON_PARAMS
            if DomUtils.hasClass(button, props.selectionClass)
                button.rzParamName = key
                return props

    _handleButtonClick: (e) =>
        button = @_getButtonBySelectionClass(e.currentTarget)
        return @__dispatchEvent(button.event, {event: e}) if button.event

    _resizeMenu: =>
        menuWidth = getEditBlockTotalWidth()
        blipWidth = @_container.parentNode?.parentNode?.offsetWidth || 0
        if menuWidth > blipWidth
            @_fitEditMenu(menuWidth - blipWidth)
        else
            @_fitEditMenu(0)
        if menuWidth + OVERFLOW_MENU_ADDITIONAL_WIDTH < blipWidth
            DomUtils.removeClass(@_container, 'at-right')
        else
            DomUtils.addClass(@_container, 'at-right')

    _getButtonToHide: (index) ->
        return null if index >= BUTTONS_ORDER.length
        BUTTON_PARAMS[BUTTONS_ORDER[index]]

    _fitEditMenu: (widthToHide) ->
        hiddenWidth = 0
        buttonsToHide = []
        index = 0
        while hiddenWidth < widthToHide
            button = @_getButtonToHide(index)
            break unless button
            buttonsToHide.push(button)
            hiddenWidth += 30 # TODO: why 30?
            index += 1
        missedButtons = @_hiddenEditButtons.filter((b) -> buttonsToHide.indexOf(b) == -1)
        for b in missedButtons
            DomUtils.removeClass(@_container, b.hiddenClass) if b.hiddenClass
        for b in buttonsToHide
            DomUtils.addClass(@_container, b.hiddenClass) if b.hiddenClass
        @_hiddenEditButtons = buttonsToHide

    _setPressed: (buttonKey, isPressed) ->
        $element = @_$container.find('.' + BUTTON_PARAMS[buttonKey].selectionClass)
        return if not $element
        if isPressed then $element.addClass('pressed')
        else $element.removeClass('pressed')

    _handleClickWhileShowingColorPanel: (event) =>
        @_hideColorPanel()

    reset: (params) ->
        @_isRoot = params.isRoot

    getContainer: -> @_container

    destroy: ->
        delete @_$calendarButton
        delete @_$fastBackButton
        delete @_$backButton
        delete @_$forwardButton
        delete @_$fastForwardButton
        delete @_container
        @_$container.remove()
        delete @_$container

    showOperationLoadingSpinner: () ->
        for button in [@_$fastBackButton, @_$backButton, @_$forwardButton, @_$fastForwardButton]
            button.attr('disabled', true)
        @_$backButton.addClass('loading')

    hideOperationLoadingSpinner: () ->
        for button in [@_$fastBackButton, @_$backButton, @_$forwardButton, @_$fastForwardButton]
            button.attr('disabled', false)
        @_$backButton.removeClass('loading')

    setCalendarDate: (date) ->
        formattedDate = formatAsShortenedDateTime(date)
        @_$calendarButton.attr('title', "Topic state at #{formattedDate}")
        @_$calendarButton.text(formattedDate)

    switchForwardButtonsState: (isDisable) ->
        @_$forwardButton.attr('disabled', isDisable)
        @_$fastForwardButton.attr('disabled', isDisable)

module.exports = {PlaybackBlipMenu}
