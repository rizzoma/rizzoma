WaveViewBase = require('./view_base')
History = require('../utils/history_navigation')
Participants = require('./participants/mobile').Participants
WaveError = require('./notification/error').WaveError
{renderWaveMobile} = require('./template')
DOM = require('../utils/dom')
Request = require('../../share/communication').Request
popup = require('../popup').popup
randomString = require('../utils/random_string').randomString
{TextLevelParams, LineLevelParams} = require('../editor/model')
BrowserSupport = require('../utils/browser_support_mobile')
BrowserEvents = require('../utils/browser_events')
BlipThread = require('../blip/blip_thread').BlipThread
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')
{KeyEventInteractor} = require('./event_interactor')
{ROLE_READER, ROLE_NO_ROLE} = require('./participants/constants')

SCROLL_HEADER_TIMER = 250

transitions = ['webkitTransition', 'mozTransition', 'transition']

class WaveMobileViewBase extends WaveViewBase
    constructor: ->
        super()
        @_backButton = null
        
    __init: (@__waveViewModel = null, participants = null) ->
        @_editable = BrowserSupport.isSupported()
        @__render()
        @__initWaveHeader(@__waveViewModel, participants)
        
    __render: ->
   
    __initWaveHeader: (waveViewModel, participants)->
        @_backButton = @container.getElementsByClassName('js-back-button')[0]
        @_backButton?.addEventListener('click', @__hideWavePanel, false)

    __hideWavePanel: =>
        return window.androidJSInterface.onTopicBackButtonClick?() if window.androidJSInterface
        History.navigateTo('', '')
        require('../modules/wave_mobile').instance.hideWavePanel()
                
    destroy: ->
        super()
        @_backButton?.removeEventListener('click', @__hideWavePanel, false)


PRESERVED_RANGE = null

class WaveView extends WaveMobileViewBase

    constructor: (@_waveViewModel, @_waveProcessor, participants, @container) ->
        ###
        @param waveViewModel: WaveViewModel
        @param _waveProcessor: WaveProcessor
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        @param container: HTMLNode, нода, в которой отображаться сообщению
        ###
        super()
        @__init(@_waveViewModel, participants)

    __init: (waveViewModel, participants) ->
        @_model = waveViewModel.getModel()
        super(waveViewModel, participants)
        @_initEditingButtons()
        @_initRootBlip(waveViewModel)
        @_initRootMenu() if BrowserSupport.isSupported()
        waveViewModel.on('unread-blips-count', @_updateUnreadBlipsCount)

    _initRootMenu: ->
        replyButton = $(@container).find('.js-root-reply-button')
        replyButton.bind 'click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Re in root menu'])
            @_waveViewModel.getLoadedBlip(@_waveViewModel.getModel()?.getRootBlipId())?.getView()?.insertReplyBlip()
        replyButton[0].disabled = no

    updateContacts: ->

    activateContacts: ->


    __initWaveHeader: (waveViewModel, participants) ->
        ###
        Инициализирует заголовок волны
        ###
        super(waveViewModel, participants)
        @_header = @container.getElementsByClassName('js-wave-header')[0]
        window.addEventListener('scroll', @_handleScroll, no)
        @_nextUnreadBlipButton.setAttribute('disabled', 'disabled')
        @_nextUnreadBlipButton.addEventListener('mousedown', @_nextUnreadHandler, false)
        @_initParticipants(waveViewModel, participants)
        $('.js-enter-rizzoma-btn').click((e) =>
            @emit('sign-in-click')
            e.stopPropagation()
            e.preventDefault()
        )

    _handleScroll: =>
        if @_scrollHeaderTimer?
            clearTimeout(@_scrollHeaderTimer)
        else
            hStyle = @_header.style
            for t in transitions
                hStyle[t] = ''
            hStyle.top = ''
        @_scrollHeaderTimer = setTimeout(@_doScroll, SCROLL_HEADER_TIMER)

    _doScroll: =>
        @_scrollHeaderTimer = null
        scrollTop = document.body.scrollTop || document.documentElement.scrollTop
        return unless scrollTop
        hStyle = @_header.style
        hStyle.opacity = '0'
        setTimeout =>
            for t in transitions
                hStyle[t] = 'opacity 0.2s linear'
            hStyle.top = "#{scrollTop}px"
            hStyle.opacity = '1'
        , 0

    updatePublicState: ->

    setSharedState: ->

    _initParticipants: (waveViewModel, participants) ->
        ###
        Инициализирует панель с участниками волны
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        ###
        @_participants = new Participants waveViewModel, @_waveProcessor, @_model.serverId, participants, yes

    _initEditingButtons: ->
        ###
        Инициализирует меню редактирования волны
        ###
        return if not @_editable
        @_initActiveBlipControls()
        @_disableEditingButtons()

    _initActiveBlipControls: ->
        ###
        Инициализирует кнопки вставки реплая или меншена в активный блиб
        ###
        if BrowserSupport.isIDevice()
            @_header.addEventListener BrowserEvents.TOUCH_END_EVENT, ->
                s = getSelection()
                PRESERVED_RANGE = if s and s.rangeCount then s.getRangeAt(0) else null
                return unless PRESERVED_RANGE
                setTimeout ->
                    PRESERVED_RANGE = null
                , 500
            , no
        insertReply = $(@container).find('.active-blip-control.js-insert-reply')
        insertReply.mousedown @_eventHandler(@_insertBlipButtonClick)
        insertMention = $(@container).find('.active-blip-control.js-insert-mention')
        insertMention.mousedown @_eventHandler(@_insertMention)
        @_$editBlipButton = $(@container).find('.js-toggle-edit-mode')
        BrowserEvents.addBlocker(@_$editBlipButton[0], 'mousedown', no)
        @_$editBlipButton.click(@_changeEditMode)
        @_activeBlipControls = []
        @_activeBlipControls.push(insertReply[0]) if insertReply[0]
        @_activeBlipControls.push(insertMention[0]) if insertMention[0]

    _nextUnreadHandler: (event) =>
        _gaq.push(['_trackEvent', 'Topic content', 'Next unread click', 'Next unread message'])
        @_goToUnread()
        event.preventDefault()
        event.stopPropagation()

    _initRootBlip: (waveViewModel) ->
        ###
        Инициализирует корневой блип
        ###
        blipNode = $(@container).find('.js-container-blip')[0]
        processor = require('../blip/processor_mobile').instance
        processor.openBlip waveViewModel, @_model.getContainerBlipId(), blipNode, null, (err, @rootBlip) =>
            if err
                @_waveProcessor.showPageError(err)
            else
                @_initRangeChangeEvent()
                hideRepliesButton = $(@container).find('.js-hide-replies-button')
                hideRepliesButton[0].disabled = no
                hideRepliesButton.click =>
                    @rootBlip.getView().foldAllChildBlips()
                    _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Root menu'])
                showRepliesButton = $(@container).find('.js-show-replies-button')
                showRepliesButton[0].disabled = no
                showRepliesButton.click =>
                    @rootBlip.getView().unfoldAllChildBlips()
                    _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Root menu'])

        @_keyInteractor = new KeyEventInteractor(blipNode)
        @_keyInteractor.on 'blip', =>
            role = @_waveViewModel.getRole()
            return if role is ROLE_NO_ROLE or role is ROLE_READER
            @_insertBlip('Shortcut')
        @on 'range-change', (range, blip) =>
            @markActiveBlip(blip) if blip
        @container.addEventListener(BrowserEvents.C_FOCUS_EVENT, @_processCActivateEvent, no)
        @container.addEventListener(BrowserEvents.C_BLIP_CREATE_EVENT, @_processCBlipCreateEvent, no)

    _processCActivateEvent: (e) =>
        @_enableEditingButtons() if not @_editingButtonsEnabled
        @markActiveBlip(e.blip)

    _processCBlipCreateEvent: =>
        @_model.setEditable(yes)

    _disableEditingButtons: ->
        @_editingButtonsEnabled = no
        for btn in @_activeBlipControls
            btn.disabled = yes

    _enableEditingButtons: ->
        return unless BrowserSupport.isSupported()
        @_editingButtonsEnabled = yes
        for btn in @_activeBlipControls
            btn.disabled = no

    _checkChangedRange: (range, blip) =>
        if range and blip.getPermission() in [EDIT_PERMISSION, COMMENT_PERMISSION]
            @_enableEditingButtons() if not @_editingButtonsEnabled
        else
            @_disableEditingButtons() if @_editingButtonsEnabled
        if blip is @_lastBlip
            return if range is @_lastRange
            if range and @_lastRange and
                    range.compareBoundaryPoints(Range.START_TO_START, @_lastRange) is 0 and
                    range.compareBoundaryPoints(Range.END_TO_END, @_lastRange) is 0
                return if blip?.getEditor().getContainer() is document.activeElement
                range = null
                blip = null
        @_lastRange = range
        @_lastRange = @_lastRange.cloneRange() if @_lastRange
        @_lastBlip = blip
        @emit('range-change', @_lastRange, blip)

    _checkRange: =>
        ###
        Проверяет положение курсора и генерирует событие изменения положения
        курсора при необходимости
        ###
        params = @_getBlipAndRange()
        if params
            @_checkChangedRange(params[1], params[0])
        else
            @_checkChangedRange(null, null)

    runCheckRange: =>
        window.setTimeout =>
            @_checkRange()
        , 0

    _handleMouseDownEvent: (e) =>
        window.setTimeout =>
            return unless @rootBlip
            params = @_getBlipAndRange()
            if params
                @_checkChangedRange(params[1], params[0])
            else
                blip = @rootBlip.getView().getBlipContainingElement(e.target)
                @_checkChangedRange(null, blip)
        , 0

    _initRangeChangeEvent: ->
        ###
        Инициализирует событие "изменение курсора"
        ###
        @_lastRange = null
        @_lastBlip = null

        window.addEventListener('keydown', @runCheckRange, false)
        if BrowserSupport.isWebKit()
            document.addEventListener('selectionchange', @runCheckRange, no)
        else
            document.addEventListener(BrowserEvents.C_EDITOR_MOUSE_DOWN_EVENT, @_handleMouseDownEvent, no)

    _eventHandler: (func) ->
        ###
        # TODO: remove it
        Возвращает функцию, которая остановит событие и вызовет переданную
        @param func: function
        @return: function
            function(event)
        ###
        (event) ->
            event.preventDefault()
            event.stopPropagation()
            func()

    __render: ->
        ###
        Создает DOM для отображения документа
        ###
        c = $(@container)
        c.empty()
        params =
            editable: @_editable
            id: @_waveViewModel.getServerId()
            isAnonymous: !window.userInfo?.id?
        c.append renderWaveMobile(params)
        @_waveContent = $(@container).find('.js-wave-content')[0]
        @_nextUnreadBlipButton = @container.getElementsByClassName('js-next-unread-button')[0]
        @_$activeBlipControls = $(@_waveContent).find('.js-active-blip-controls')

    __scrollToBlipContainer: (blipContainer) ->
        DOM.scrollTargetIntoView(blipContainer, document.body, yes, -75)

    markActiveBlip: (blip) =>
        ###
        @param blip: BlipView
        ###
        # TODO: work with BlipViewModel only
        return if @_activeBlip is blip
        if @_activeBlip
            @_activeBlip.unmarkActive()
        hasEditPermission = blip && blip.hasEditPermission()
        if @_model.getEditable()
            @_activeBlip?.setEditable(no)
            blip.setEditable(hasEditPermission)
            @_model.setEditable(hasEditPermission)
        if hasEditPermission
            @_$editBlipButton.removeAttr('disabled')
        else
            @_$editBlipButton.attr('disabled', 'disabled')
        @_activeBlip = blip
        @_model.setActiveBlip(blip.getViewModel())
        @_activeBlip.markActive()

    _expandCrossedBlipRange: (range, blipViewStart, blipViewEnd, directionForward) ->
        if blipViewEnd
            start = []
            end = []
            startView = blipViewStart
            while startView
                start.push(startView)
                startView = startView.getParent()
            endView = blipViewEnd
            while endView
                end.push(endView)
                endView = endView.getParent()
            while (startView = start.pop()) is (endView = end.pop())
                commonView = startView
            if startView
                startThread = BlipThread.getBlipThread(startView.getContainer())
                startViewContainer = startThread.getContainer()
                range.setStartBefore(startViewContainer)
                if @_lastRange
                    if range.compareBoundaryPoints(Range.START_TO_START, @_lastRange) > -1
                        range.setStartAfter(startViewContainer)
            if endView
                endThread = BlipThread.getBlipThread(endView.getContainer())
                endViewContainer = endThread.getContainer()
                range.setEndAfter(endViewContainer)
                if @_lastRange
                    if range.compareBoundaryPoints(Range.END_TO_END, @_lastRange) < 1
                        range.setEndBefore(endViewContainer)
        else
            el = blipViewStart.getEditor()?.getContainer()
            commonView = blipViewStart
            range.setEnd(el, el.childNodes.length) if el
        DOM.setRange(range, directionForward)
        return [commonView, range]

    _getBlipAndRange: ->
        ###
        Возвращает текущее выделение и блип, в котором оно сделано
        @return: [BlipView, DOM range]|null
        ###
        return null if not @rootBlip
        selection = window.getSelection()
        if selection and selection.rangeCount
            range = selection.getRangeAt(0)
        else
            range = PRESERVED_RANGE
            DOM.setRange(range) if range
        return null if not range
        cursor = [range.startContainer, range.startOffset]
        directionForward = if selection.anchorNode is range.startContainer and selection.anchorOffset is range.startOffset then yes else no
        blipViewStart = @rootBlip.getView().getBlipContainingCursor(cursor)
        unless blipViewStart
#            selection.removeAllRanges()
            return null
        cursor = [range.endContainer, range.endOffset]
        blipViewEnd = if range.collapsed then blipViewStart else @rootBlip.getView().getBlipContainingCursor(cursor)
        if blipViewStart isnt blipViewEnd
            return @_expandCrossedBlipRange(range, blipViewStart, blipViewEnd, directionForward)
        return [blipViewStart, range]

    _changeEditMode: =>
        return console.warn('no active blip') unless @_activeBlip
        editable = @_model.getEditable()
        @_activeBlip.setEditable(!editable)
        @_model.setEditable(!editable)

    _insertBlip: (analyticsLabel) ->
        ###
        Обрабатывает нажатие на кнопку вставки комментария
        ###
        opParams = @_getBlipAndRange()
        return if not opParams
        _gaq.push(['_trackEvent', 'Blip usage', analyticsLabel])
        [blip, range] = opParams
        blipViewModel = blip.initInsertInlineBlip()
        #TODO: do we really need it here
        blipViewModel.getView().focus()
        window.setTimeout =>
            params = @_getBlipAndRange()
            return unless params
            @_checkChangedRange(params[1], params[0])
        , 0

    _insertBlipButtonClick: =>
        @_insertBlip('Re in editing menu')

    _insertMention: =>
        params = @_getBlipAndRange()
        return unless params
        [blip, range] = params
        recipientInput = blip.getEditor().insertRecipient()
        recipientInput?.insertionEventLabel = 'Menu button'

    _goToUnread: =>
        ###
        Переводит фокус на первый непрочитаный блип,
        расположенный после блипа под фокусом
        ###
        @emit('goToNextUnread')
        @_activeBlip.markAsRead()
        window.getSelection()?.removeAllRanges()
        @_checkRange()

    getActiveBlip: ->
        #TODO: hack activeBlip
        @_activeBlip.getViewModel()

    getRootBlip: ->
        @rootBlip

    processEditableChange: (editable) ->
        text = if editable then 'Done' else 'Edit'
        @_$editBlipButton.html("<span>#{text}</span>")

    destroy: ->
        super()
        @_keyInteractor.destroy()
        delete @_keyInteractor
        require('../editor/file/upload_form').removeInstance()
        @removeAllListeners()
        @container.removeEventListener(BrowserEvents.C_FOCUS_EVENT, @_processCActivateEvent, no)
        @container.removeEventListener(BrowserEvents.C_BLIP_CREATE_EVENT, @_processCBlipCreateEvent, no)
        window.removeEventListener 'keydown', @runCheckRange, false
        if BrowserSupport.isWebKit()
            document.removeEventListener('selectionchange', @runCheckRange, no)
        else
            document.removeEventListener(BrowserEvents.C_EDITOR_MOUSE_DOWN_EVENT, @_handleMouseDownEvent, no)
        window.removeEventListener('scroll', @_handleScroll, no)
        clearTimeout(@_scrollHeaderTimer) if @_scrollHeaderTimer?
        @_header = null
        @_nextUnreadBlipButton.removeEventListener('mousedown', @_nextUnreadHandler, false)
        $(@container).empty().unbind()
        delete @rootBlip
        delete @_activeBlip if @_activeBlip
        delete @_lastBlip if @_lastBlip
        delete @_$editBlipButton
        @_participants.destroy()
        delete @_participants
        # hack - clean jQuery's cached fragments
        jQuery.fragments = {}

    applyParticipantOp: (op) ->
        @_participants.applyOp op
        return if not window.loggedIn
        isMyOp = op.ld?.id is window.userInfo.id or op.li?.id is window.userInfo.id
        return if not isMyOp
        @updateInterfaceAccordingToRole()

    updateInterfaceAccordingToRole: ->
        @_waveViewModel.updateParticipants()
        @rootBlip.getView().recursivelyUpdatePermission()

    getParticipantIds: ->
        @_participants.all()

    _updateUnreadBlipsCount: (count) =>
        ###
        Обновляет количество непрочитанных сообщений для волны
        и дизэблит кнопку Next если нет непрочитанных
        @param count: int
        ###
        if count == 0
            @_nextUnreadBlipButton.setAttribute('disabled', 'disabled')
        else
            if @_nextUnreadBlipButton.hasAttribute('disabled')
                @_nextUnreadBlipButton.removeAttribute('disabled', 0)

    getSocialSharingUrl: ->

module.exports =
    WaveView: WaveView
