{renderBlipMenu} = require('./template')
{TextLevelParams, LineLevelParams} = require('../../editor/model')
{formatDate} = require('../../../share/utils/datetime')
BrowserEvents = require('../../utils/browser_events')
DomUtils = require('../../utils/dom')
{Interactable} = require('../../utils/interactable')
{BlipEventTypes} = require('../interactor/blip_events')

# Цвета, которые можно установить из редактора
COLORS = [
    null,       # снимает цвет
    '#FFE066'
    '#B5EB5E'
    '#8AE5D6'
    '#AAB2F2'
    '#DAB6F2'
    '#F2A79D'
]

# Список всех возможных модификаторов текста и ключи в buttonParams, которым они соответствуют
TEXT_MODIFIERS = {}
TEXT_MODIFIERS[TextLevelParams.BOLD] = 'makeBoldButton'
TEXT_MODIFIERS[TextLevelParams.ITALIC] = 'makeItalicButton'
TEXT_MODIFIERS[TextLevelParams.UNDERLINED] = 'makeUnderlinedButton'
TEXT_MODIFIERS[TextLevelParams.STRUCKTHROUGH] = 'makeStruckthroughButton'
TEXT_MODIFIERS[TextLevelParams.BG_COLOR] = null # Не даем ссылку на кнопку, чтобы ей не проставлялось автоматическое нажатие

# Список всех возможных параметров строк и ключи в buttonParams, которым они соответствуют
LINE_MODIFIERS_MAP = {}
LINE_MODIFIERS_MAP[LineLevelParams.BULLETED] = 'makeBulletedListButton'
LINE_MODIFIERS_MAP[LineLevelParams.NUMBERED] = 'makeNumberedListButton'

BUTTONS_ORDER = ['makeUnderlinedButton', 'makeStruckthroughButton', 'delete', 'manageLinkButton',
                'makeItalicButton', 'makeBoldButton', 'makeBulletedListButton', 'makeNumberedListButton',
                'makeBgColorButton', 'clearFormattingButton', 'undoButton', 'redoButton', 'insertImageButton',
                'insertFileButton', 'foldedByDefault']

FOLD_UNFOLD_BLOCK_HIDDEN_CLASS = 'fold-unfold-block-hidden'

BUTTON_PARAMS =
    changeMode:
        selectionClass: 'js-change-mode'
        event: BlipEventTypes.CHANGE_MODE
    undoButton:
        hiddenClass: 'undo-button-hidden'
        selectionClass: 'js-undo'
        event: BlipEventTypes.UNDO
    redoButton:
        hiddenClass: 'redo-button-hidden'
        selectionClass: 'js-redo'
        event: BlipEventTypes.REDO
    insertFileButton:
        hiddenClass: 'insert-file-button-hidden'
        selectionClass: 'js-insert-file'
        event: BlipEventTypes.INSERT_FILE
    insertImageButton:
        hiddenClass: 'insert-image-button-hidden'
        selectionClass: 'js-insert-image'
        event: BlipEventTypes.INSERT_IMAGE
    manageLinkButton:
        hiddenClass: 'manage-link-button-hidden'
        selectionClass: 'js-manage-link'
        event: BlipEventTypes.MANAGE_LINK
    makeBoldButton:
        hiddenClass: 'bold-button-hidden'
        selectionClass: 'js-make-bold'
        event: BlipEventTypes.MAKE_BOLD
    makeItalicButton:
        hiddenClass: 'italic-button-hidden'
        selectionClass: 'js-make-italic'
        event: BlipEventTypes.MAKE_ITALIC
    makeUnderlinedButton:
        hiddenClass: 'underline-button-hidden'
        selectionClass: 'js-make-underlined'
        event: BlipEventTypes.MAKE_UNDERLINED
    makeStruckthroughButton:
        hiddenClass: 'struckthrough-button-hidden'
        selectionClass: 'js-make-struckthrough'
        event: BlipEventTypes.MAKE_STRUCKTHROUGH
    makeBgColorButton:
        hiddenClass: 'bg-color-button-hidden'
        selectionClass: 'js-make-background-color'
    clearFormattingButton:
        hiddenClass: 'clear-formatting-button-hidden'
        selectionClass: 'js-clear-formatting'
        event: BlipEventTypes.CLEAR_FORMATTING
    makeBulletedListButton:
        hiddenClass: 'bulleted-list-button-hidden'
        selectionClass: 'js-make-bulleted-list'
        event: BlipEventTypes.MAKE_BULLETED
    makeNumberedListButton:
        hiddenClass: 'numbered-list-button-hidden'
        selectionClass: 'js-make-numbered-list'
        event: BlipEventTypes.MAKE_NUMBERED
    foldedByDefault:
        hiddenClass: 'is-folded-by-default-button-hidden'
        selectionClass: 'js-is-folded-by-default'
        event: BlipEventTypes.SET_FOLDED_BY_DEFAULT
    delete:
        hiddenClass: 'delete-button-hidden'
        selectionClass: 'js-delete-blip'
        event: BlipEventTypes.DELETE
    copyLink:
        selectionClass: 'js-copy-blip-link'
        event: BlipEventTypes.SHOW_BLIP_URL
    foldAll:
        selectionClass: 'js-hide-all-inlines'
        event: BlipEventTypes.FOLD_ALL
    unfoldAll:
        selectionClass: 'js-show-all-inlines'
        event: BlipEventTypes.UNFOLD_ALL
    copyBlipButton:
        selectionClass: 'js-copy-blip-button'
        event: BlipEventTypes.COPY_BLIP
    pasteAsReply:
        selectionClass: 'js-paste-after-blip-button'
        event: BlipEventTypes.PASTE_AS_REPLY
    pasteAtCursor:
        selectionClass: 'js-paste-at-cursor-button'
        event: BlipEventTypes.PASTE_AT_CURSOR
    sendButton:
        selectionClass: 'js-send-button'
        event: BlipEventTypes.SEND
    playbackButton:
        selectionClass: 'js-playback-button'
        event: BlipEventTypes.PLAYBACK

# Дополнительная ширина меню, создаваемая всплывающим меню при нажатии на шестеренку
OVERFLOW_MENU_ADDITIONAL_WIDTH = 60
ADDITIONAL_MENU_WIDTH = 15 # adding space for changing Hide to Hidden
TOTAL_WIDTH = null

getMenuDom = ->
    tmpEl = document.createElement('span')
    tmpEl.className = 'blip-menu'
    tmpEl.appendChild(DomUtils.parseFromString(renderBlipMenu()))
    tmpEl

getTotalWidth = ->
    tmpEl = getMenuDom()
    document.body.appendChild(tmpEl)
    editBlock = tmpEl.getElementsByClassName('js-edit-block')[0]
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

class BlipMenu extends Interactable
    constructor: ->
        super()
        @_hiddenEditButtons = []
        # TODO: do we need it?
        @_container = getMenuDom()
        @_$container = $(@_container)
        @_editBlock = @_container.getElementsByClassName('js-edit-block')[0]
        @_readOnlyBlock = @_container.getElementsByClassName('js-read-only-block')[0]
        @_editBlockOtherBlipMenu = @_editBlock.getElementsByClassName('js-other-blipmenu-container')[0]
        @_readOnlyBlockOtherBlipMenu = @_readOnlyBlock.getElementsByClassName('js-other-blipmenu-container')[0]
        @_colorPanel = @_editBlock.getElementsByClassName('js-color-panel')[0]
        @_sendButton = @_editBlock.getElementsByClassName(BUTTON_PARAMS.sendButton.selectionClass)[0]
        @_foldAllButton = @_container.getElementsByClassName(BUTTON_PARAMS.foldAll.selectionClass)
        @_$bgColorButtonIcon = @_$container.find('.' + BUTTON_PARAMS.makeBgColorButton.selectionClass).find('.js-icon')
        @_$changeModeButton = @_$container.find('.' + BUTTON_PARAMS.changeMode.selectionClass)
        @_$foldedByDefaultButtons = @_$container.find('.' + BUTTON_PARAMS.foldedByDefault.selectionClass)
        $editBlock = $(@_editBlock)
        @_$undoButton = $editBlock.find('.' + BUTTON_PARAMS.undoButton.selectionClass)
        @_$redoButton = $editBlock.find('.' + BUTTON_PARAMS.redoButton.selectionClass)

        @_initButtons()
        BrowserEvents.addBlocker(@_container, BrowserEvents.MOUSE_DOWN_EVENT)
        BrowserEvents.addBlocker(@_container, BrowserEvents.MOUSE_UP_EVENT)
        BrowserEvents.addBlocker(@_container, BrowserEvents.CLICK_EVENT)

    _initButtons: ->
        @_$container.find('.js-make-background-color').click(@_handleBgColorButtonClick)
        @_$container.find('.js-gearwheel').click(@_handleGearWheelButtonClick)
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

    _hideOtherMenu: ->
        DomUtils.removeClass(@_container, 'show-other-menu')
        document.removeEventListener(BrowserEvents.CLICK_EVENT, @_handleClickForOtherMenu, yes)

    _showOtherMenu: ->
        DomUtils.addClass(@_container, 'show-other-menu')
        document.addEventListener(BrowserEvents.CLICK_EVENT, @_handleClickForOtherMenu, yes)

    _handleClickForOtherMenu: (e) =>
        target = e.target
        return if @_editBlockOtherBlipMenu is target or @_readOnlyBlockOtherBlipMenu is target
        return if DomUtils.contains(@_editBlockOtherBlipMenu, target)
        return if DomUtils.contains(@_readOnlyBlockOtherBlipMenu, target)
        e.stopPropagation()
        @_hideOtherMenu()

    _handleGearWheelButtonClick: (e) =>
        e.stopPropagation()
        if DomUtils.hasClass(@_container, 'show-other-menu') then @_hideOtherMenu() else @_showOtherMenu()

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

    _updateLineButtonsState: (params) ->
        for key, buttonKey of LINE_MODIFIERS_MAP
            @_setPressed(buttonKey, params[key]?)

    _updateTextButtonsState: (params) ->
        hasModifiers = false
        for key, buttonKey of TEXT_MODIFIERS
            @_setPressed(buttonKey, !!params[key]) if buttonKey
            hasModifiers ||= !!params[key]
        @_updateBgColorButton(params[TextLevelParams.BG_COLOR])

    _updateBgColorButton: (currentColor = null) ->
        ###
        Обновляет цвет на фоне кнопки изменения цвета
        ###
        @_currentBgColor = currentColor
        return @_$bgColorButtonIcon.css('background-color', 'white') if currentColor
        @_$bgColorButtonIcon.css('background-color', COLORS[@_lastColorChoice] || 'white')

    _setBgColor: (color = null) -> @__dispatchEvent(BlipEventTypes.SET_BG_COLOR, {value: color})

    _bgColorButtonHandler: (choice) =>
        color = COLORS[choice]
        @_lastColorChoice = choice or 0
        @_updateBgColorButton(color)
        @_setBgColor(color)
        @_hideColorPanel()

    _handleClickWhileShowingColorPanel: (event) =>
        target = event.target
        @_hideColorPanel() if not (target is @_makeBgColorButton or target is @_colorPanel or $.contains(@_colorPanel, target))

    _showColorPanel: ->
        unless @_backgroundPanelInited
            i = 0
            colorChoice = @_colorPanel.firstChild
            while colorChoice
                $(colorChoice).css('background-color', COLORS[i] || 'white')
                    .on 'mousedown', do (i) => ()  => @_bgColorButtonHandler(i)
                colorChoice = colorChoice.nextSibling
                i++
            @_backgroundPanelInited = yes
            @_lastColorChoice = COLORS.indexOf(@_currentBgColor or null)
        choice = @_colorPanel.childNodes[@_lastColorChoice] if @_lastColorChoice?
        $(@_colorPanel).find('.color-choice').removeClass('active')
        $(choice).addClass('active')
        @_colorPanel.style.display = 'block'
        window.addEventListener 'mousedown', @_handleClickWhileShowingColorPanel, yes
        window.addEventListener 'keydown', @_hideColorPanel, yes

    _hideColorPanel: =>
        @_colorPanel.style.display = 'none'
        window.removeEventListener 'mousedown', @_handleClickWhileShowingColorPanel, yes
        window.removeEventListener 'keydown', @_hideColorPanel, yes

    _handleBgColorButtonClick: (e) =>
        e.stopPropagation()
        _gaq.push(['_trackEvent', 'Blip usage', 'Make text background colored'])
        currentColor = @_currentBgColor
        if currentColor or not @_lastColorChoice
            @_setBgColor()
            currentColor = null
        else
            currentColor = COLORS[@_lastColorChoice]
            @_setBgColor(currentColor)
        @_updateBgColorButton(currentColor)
        if not $(@_colorPanel).is(':visible')
            @_showColorPanel(currentColor)
            return
        @_hideColorPanel()

    _updateFoldUnfoldButtons: ->
        if @_foldable
            DomUtils.removeClass(@_container, FOLD_UNFOLD_BLOCK_HIDDEN_CLASS)
        else
            DomUtils.addClass(@_container, FOLD_UNFOLD_BLOCK_HIDDEN_CLASS)

    _updateSendButton: (text = '') ->
        if @_sendable
            DomUtils.removeClass(@_sendButton, 'hidden')
        else
            DomUtils.addClass(@_sendButton, 'hidden')
        $(@_sendButton).text(text) if text
        if @_lastSent
            if @_lastSender
                lastSentStr = "Sent on #{formatDate(@_lastSent)} by #{@_lastSender}"
            else
                lastSentStr = "Automatically sent on #{formatDate(@_lastSent)}"
        else
            lastSentStr = 'Has not been sent yet'
        @_sendButton.title = lastSentStr

    _setCanEdit: (canEdit) ->
        @_canEdit = canEdit
        if canEdit
            DomUtils.removeClass(@_container, 'hide-copy-paste')
            DomUtils.removeClass(@_foldAllButton, 'start-blip-menu') # TODO: think about this class
            @_$changeModeButton.show()
        else
            DomUtils.addClass(@_container, 'hide-copy-paste')
            DomUtils.addClass(@_foldAllButton, 'start-blip-menu')
            @_$changeModeButton.hide()
        if canEdit and not @_isRoot
            DomUtils.removeClass(@_container, 'is-folded-by-default-button-hidden-force')
            DomUtils.removeClass(@_container, 'delete-button-hidden-force')
        else
            DomUtils.addClass(@_container, 'is-folded-by-default-button-hidden-force')
            DomUtils.addClass(@_container, 'delete-button-hidden-force')

    _setDisabled: ($button, disabled) ->
        if disabled
            $button.attr('disabled', 'disabled')
        else
            $button.removeAttr('disabled')

    _setFoldedByDefault: (folded) ->
        return if folded is @_foldedByDefault
        if folded
            DomUtils.addClass(@_container, 'folded-by-default')
            @_$foldedByDefaultButtons.text('Hidden')
            @_$foldedByDefaultButtons.prop('title', 'This thread is collapsed by default. Click to change')
        else
            DomUtils.removeClass(@_container, 'folded-by-default')
            @_$foldedByDefaultButtons.text('Hide')
            @_$foldedByDefaultButtons.prop('title', 'Collapse this thread by default')
        @_foldedByDefault = folded

    _disableIdDependantButtons: ->
        # TODO: cache this buttons
        @_$container.find('.js-gearwheel').prop('disabled', yes)
        @_$container.find('.js-copy-blip-link').prop('disabled', yes)

    _enableIdDependantButtons: ->
        @_$container.find('.js-gearwheel').prop('disabled', no)
        @_$container.find('.js-copy-blip-link').prop('disabled', no)

    reset: (params) ->
        @_foldable = params.foldable
        @_sendable = params.sendable
        @_foldedByDefault = null
        @_lastSent = params.lastSent
        @_lastSender = params.lastSender

        @_isRoot = params.isRoot
        if params.hasServerId
            @_enableIdDependantButtons()
        else
            @_disableIdDependantButtons()
        @_setCanEdit(params.canEdit)
        @_setFoldedByDefault(params.foldedByDefault)
        @_hideOtherMenu()
        @_updateSendButton('Send')

    setEditMode: ->
        DomUtils.addClass(@_readOnlyBlock, 'hidden')
        DomUtils.removeClass(@_editBlock, 'hidden')
        @_resizeMenu()
        $(window).on('resize resizeTopicByResizer', @_resizeMenu)

    setReadMode: ->
        DomUtils.addClass(@_editBlock, 'hidden')
        DomUtils.removeClass(@_readOnlyBlock, 'hidden')
        $(window).off('resize resizeTopicByResizer', @_resizeMenu)
        @_updateFoldUnfoldButtons()

    setFoldedByDefault: (folded) -> @_setFoldedByDefault(folded)

    setCanEdit: (canEdit) ->
        @_setCanEdit(canEdit)

    setLastSent: (lastSent, lastSender) ->
        return if lastSent is @_lastSent and lastSender is @_lastSender
        @_lastSent = lastSent
        @_lastSender = lastSender
        @_updateSendButton()

    setFoldable: (foldable) ->
        return if foldable is @_foldable
        @_foldable = foldable
        @_updateFoldUnfoldButtons()

    setUndoButtonDisabled: (disabled) -> @_setDisabled(@_$undoButton, disabled)

    setRedoButtonDisabled: (disabled) -> @_setDisabled(@_$redoButton, disabled)

    setSendable: (sendable) ->
        return if sendable is @_sendable
        @_sendable = sendable
        @_updateSendButton()

    updateSendButton: (text) -> @_updateSendButton(text)

    setLineParams: (params) -> @_updateLineButtonsState(params)

    setTextParams: (params) -> @_updateTextButtonsState(params)

    getContainer: -> @_container

    enableIdDependantButtons: -> @_enableIdDependantButtons()

    detach: ->
        # TODO: do not use it. Should be removed
        $(window).off('resize resizeTopicByResizer', @_resizeMenu)

    destroy: ->
        document.removeEventListener(BrowserEvents.CLICK_EVENT, @_handleMouseDownForOtherMenu, yes)
        @detach()
        delete @_editBlock
        delete @_readOnlyBlock
        delete @_editBlockOtherBlipMenu
        delete @_readOnlyBlockOtherBlipMenu
        delete @_colorPanel
        delete @_$undoButton
        delete @_$redoButton
        delete @_sendButton
        delete @_$changeModeButton
        delete @_foldAllButton
        delete @_$bgColorButtonIcon
        delete @_container
        @_$container.remove()
        delete @_$container
        delete @_hiddenEditButtons
        delete @_$foldedByDefaultButtons

module.exports = {TEXT_MODIFIERS, BlipMenu}
