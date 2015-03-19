WaveViewBase = require('./view_base')
{Participants} = require('./participants')
{trackParticipantAddition} = require('./participants/utils')
{ROLES, ROLE_OWNER, ROLE_EDITOR, ROLE_COMMENTATOR, ROLE_READER, ROLE_NO_ROLE} = require('./participants/constants')
{renderWave, renderSelectAccountTypeBanner} = require('./template')
DOM = require('../utils/dom')
popup = require('../popup').popup
randomString = require('../utils/random_string').randomString
{TextLevelParams, LineLevelParams} = require('../editor/model')
BrowserSupport = require('../utils/browser_support')
{SettingsMenu} = require('./settings_menu')
{AccountMenu} = require('./account_menu')
{isEmail, strip} = require('../utils/string')
{WAVE_SHARED_STATE_PUBLIC, WAVE_SHARED_STATE_LINK_PUBLIC, WAVE_SHARED_STATE_PRIVATE} = require('./model')
BlipThread = require('../blip/blip_thread').BlipThread
AddParticipantForm = require('./participants/add_form').AddParticipantForm
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')
{RoleSelectPopup} = require('./role_select_popup')
{LocalStorage} = require('../utils/localStorage')
{MindMap} = require('../mindmap')
RangeMenu = require('../blip/menu/range_menu')
History = require('../utils/history_navigation')
BrowserEvents = require('../utils/browser_events')

SCROLL_INTO_VIEW_OFFSET = -90

ADD_BUTTONS = []
for role in ROLES when role.id isnt ROLE_OWNER
    ADD_BUTTONS.push {
        id: role.id
        name: role.name.toLowerCase()
    }

DEFAULT_ROLES = [
    [ROLE_EDITOR, 'edit']
    [ROLE_COMMENTATOR, 'comment']
    [ROLE_READER, 'read']
]


class WaveView extends WaveViewBase
    constructor: (@_waveViewModel, @_waveProcessor, participants, @_container) ->
        ###
        @param waveViewModel: WaveViewModel
        @param _waveProcessor: WaveProcessor
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        @param container: HTMLNode, нода, в которой отображаться сообщению
        ###
        super()
        @container = @_container # TODO: deprecated. backward compatibility
        @_init(@_waveViewModel, participants)

    _init: (waveViewModel, participants) ->
        ###
        @param waveViewModel: WaveViewModel
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        ###
        @_inEditMode = no
        @_isAnonymous = !window.userInfo?.id?
        @_model = waveViewModel.getModel()
        @_editable = BrowserSupport.isSupported() and not @_isAnonymous
        @_createDOM(renderWave)
        @_initWaveHeader(waveViewModel, participants)
        @_initEditingMenu()
        @_updateParticipantsManagement()
        @_initRootBlip(waveViewModel)
        @_updateReplyButtonState()
        @_initTips()
        @_initDragScroll()
        waveViewModel.on('waveLoaded', =>
            $(@_waveBlips).on 'scroll', @_setOnScrollMenuPosition
            $(window).on('scroll', @_setOnScrollMenuPosition)
            $(window).on 'resize resizeTopicByResizer', @_resizerRepositionMenu
        )
        @_initBuffer()
        @_$wavePanel.addClass('visible') if not BrowserSupport.isSupported() and not @_isAnonymous

    _contactSelectHandler: (item) =>
        @_$participantIdInput.val(item.email) if item? and item
        @_processAddParticipantClick()

    _contactButtonHandler: (e) =>
        source = $(e.currentTarget).attr('source')
        _gaq.push(['_trackEvent', 'Contacts synchronization', 'Synchronize contacts click', "add users #{source}"])
        @_waveProcessor.initContactsUpdate source, e.screenX-630, e.screenY, =>
            return if @_closed
            @activateContacts(source)
            _gaq.push(['_trackEvent', 'Contacts synchronization', 'Successfull synchronization', "add users #{source}"])

    activateContacts: (source) ->
        @_addParticipantForm?.refreshContacts(source)

    _getRole: ->
        role = @_waveViewModel.getRole()
        for r in ROLES
            if r.id == role
                return r

    _initWaveHeader: (waveViewModel, participants)->
        ###
        Инициализирует заголовок волны
        ###
        @_reservedHeaderSpace = 0
        $c = $(@container)
        @_waveHeader = $c.find('.js-wave-header')[0]
        @_$wavePanel = $c.find('.js-wave-panel')
        @_initParticipantAddition()
        @_initParticipants(waveViewModel, participants)
        if @_isAnonymous
            $c.find('.js-enter-rizzoma-btn').click (e) ->
                window.AuthDialog.initAndShow(true, History.getLoginRedirectUrl())
                e.stopPropagation()
                e.preventDefault()
        @_initWaveShareMenu()
        @_curView = 'text'
        role = @_getRole()
        $(@_waveHeader).find('.js-account-section-role').text(role.name) if role
        @_initSavingMessage()
        @_initSettingsMenu()
        @_initAccountMenu()
        @_initSelectAccountTypeBanner()

    _initSelectAccountTypeBanner: ->
        return if !window.showAccountSelectionBanner
        $(@container).prepend(renderSelectAccountTypeBanner())
        $(@container).find(".js-open-account-select").on "click", =>
            _gaq.push(['_trackEvent', 'Monetization', 'Upgrade account link click'])
            $('.js-account-wizard-banner').remove()
            delete window.showAccountSelectionWizard
            delete window.showAccountSelectionBanner
            @_waveProcessor.openAccountWizard()
        $(@container).find('.js-account-wizard-banner').on "click", ->
            $('.js-account-wizard-banner').remove()

    _initParticipantAddition: ->
        return if @_isAnonymous
        @_$addParticipantsBlock = $(@_waveHeader).find('.js-add-form')
        @_addParticipantsBlockButton = DOM.findAndBind($(@_waveHeader), '.js-add-block-button', 'click', @_processAddParticipantBlockClick)

    _processAddButtonChange: =>
        @_addButtonRole = parseInt(@_$addButtonSelect.val())

    _createAddParticipantForm: ->
        maxResults = if History.isEmbedded() then 5 else 7
        @_addParticipantForm = new AddParticipantForm(@_$addParticipantsBlock, maxResults, ADD_BUTTONS, @_waveProcessor, @_contactSelectHandler, @_contactButtonHandler)
        @_$participantIdInput = @_$addParticipantsBlock.find('.js-input-email')
        setTimeout =>
            @_$addButtonSelect = @_$addParticipantsBlock.find('.js-add-select')
            @_$addButtonSelect.selectBox().change(@_processAddButtonChange)
            @_$addButtonSelect.on 'close', =>
                window.setTimeout =>
                    $(@_participantIdInput).focus()
                0
            @_$addButton = @_$addParticipantsBlock.find('.js-add-button')
            @_updateParticipantAddition()
        ,0

    _processAddParticipantBlockClick: (event) =>
        if @_addParticipantForm?.isVisible()
            @_addParticipantForm.hide()
        else
            if not @_addParticipantForm?
                @_createAddParticipantForm()
            @_addParticipantForm.show()
            @_$participantIdInput.focus()

    _initSocialShareButtons: ->
        socialSection = $(@_waveHeader).find('.js-social-section')
        @_facebookButton = socialSection.find('.js-social-facebook')
        @_twitterButton = socialSection.find('.js-social-twitter')
        @_googleButton = socialSection.find('.js-social-google')
        @_socialOverlay = socialSection.find('.js-social-overlay')
        loadWnd = (title, url, e) =>
            wnd = window.open("/share_topic_wait/", title, "width=640,height=440,left=#{e.screenX-630},top=#{e.screenY},scrollbars=no")
            if @_waveProcessor.rootRouterIsConnected()
                @_waveProcessor.markWaveAsSocialSharing(@_model.serverId, () =>
                    wnd.document.location.href = url if wnd
                )
            else
                wnd.document.location.href = url

        @_facebookButton.on 'click', (e) =>
            _gaq.push(['_trackEvent', 'Topic sharing', 'Share topic on Facebook'])
            mixpanel.track('Topic sharing', {'channel': 'Facebook'})
            loadWnd('Facebook', "http://www.facebook.com/sharer/sharer.php?u=#{encodeURIComponent(@getSocialSharingUrl())}", e)
            return false

        @_googleButton.on 'click', (e) =>
            _gaq.push(['_trackEvent', 'Topic sharing', 'Share topic on Google+'])
            mixpanel.track('Topic sharing', {'channel': 'Google+'})
            loadWnd('Google', "https://plus.google.com/share?url=#{encodeURIComponent(@getSocialSharingUrl())}", e)
            return false

        twUrl = @getSocialSharingUrl()
        twhashtag = '#rizzoma'
        tweetLength = 140 - twUrl.length - twhashtag.length
        @_twitterButton.on 'click', (e) =>
            _gaq.push(['_trackEvent', 'Topic sharing', 'Share topic on Twitter'])
            mixpanel.track('Topic sharing', {'channel': 'Twitter'})
            snippet = ''
            for t in @rootBlip.getModel().getSnapshotContent()
                break if snippet.length >= tweetLength
                if t.params.__TYPE != 'TEXT'
                    snippet += " "
                else
                    snippet += t.t
            if snippet.length >= tweetLength
                snippet = snippet.substr(0, tweetLength-3)
                snippet += "...#{twhashtag}"
            else
                snippet += " #{twhashtag}"
            window.open("https://twitter.com/intent/tweet?source=tw&text=#{encodeURIComponent(snippet)}&url=#{encodeURIComponent(twUrl)}", 'Twitter', "width=640,height=290,left=#{e.screenX-630},top=#{e.screenY},scrollbars=no")
            return false

    _shareButtonHandler: (e) =>
        waveUrl = @_sharePopup.find('.js-wave-url')
        if @_sharePopup.is(':visible')
            return @_sharePopup.hide()
        @_sharePopup.show()
        _gaq.push(['_trackEvent', 'Topic sharing', 'Topic sharing manage'])
        waveUrl.select()
        waveUrl.on 'mousedown', =>
            waveUrl.select()
        # Обработчик на закрывание устанавливается с задержкой, чтобы не обработать
        # текущий клик
        window.setTimeout =>
            $(document).on 'click.shareWaveBlock', (e) =>
                if $(e.target).closest('.js-share-window, .js-role-selector-popup').length == 0
                    @_sharePopup.hide()
                    $(document).off('click.shareWaveBlock')
                true
        , 0
        #эта проверка нужна в ff, без нее не прячутся панели
        @_checkRange()

    _handleGDriveViewShareButton: (e) =>
        menu = @_shareContainer.find('.js-gdrive-share-menu')
        if menu.is(':visible')
            return menu.hide()
        menu.show()
        window.setTimeout =>
            $(document).on 'click.gDriveShareMenu', (e) =>
                if $(e.target).closest('.js-gdrive-share-menu').length == 0
                    menu.hide()
                    $(document).off('click.gDriveShareMenu')
                true
        , 0
        #эта проверка нужна в ff, без нее не прячутся панели
        @_checkRange()

    _initWaveShareMenu: ->
        ###
        Инициализирует меню расшаривания волны
        ###
        return if @_isAnonymous
        @_shareContainer = $(@_waveHeader).find('.js-share-container')
        @_shareButton = @_shareContainer.find('.js-show-share-button')
        @_sharePopup = @_shareContainer.find('.js-share-window')
        if History.isGDrive()
            menu = @_shareContainer.find('.js-gdrive-share-menu')
            menu.on 'click', 'a.js-btn', (e) ->
                e.preventDefault()
                menu.hide()
                $(document).off('click.gDriveShareMenu')
            @_shareButton.on('click', @_handleGDriveViewShareButton)
            @_shareContainer.find('.js-share-window-button').on('click', @_shareButtonHandler)
        else
            @_shareButton.on('click', @_shareButtonHandler)
        if not BrowserSupport.isSupported() or !window.loggedIn
            ###
            Не авторизованные пользователи или пользователи
            не под Chrome не могут расшарить волну
            ###
            @_shareButton.attr('disabled', 'disabled')
        $c = $(@container)
        @_byLinkRoleId = ROLE_EDITOR
        @_publicRoleId = ROLE_COMMENTATOR
        @_isPrivateButton = DOM.findAndBind $c, '.js-is-private-button', 'change', =>
            @setSharedState(WAVE_SHARED_STATE_PRIVATE) if @_isPrivateButton.checked
        @_isByLinkButton = DOM.findAndBind $c, '.js-by-link-button', 'change', =>
            @setSharedState(WAVE_SHARED_STATE_LINK_PUBLIC, @_byLinkRoleId) if @_isByLinkButton.checked
        @_isPublicButton = DOM.findAndBind $c, '.js-is-public-button', 'change', =>
            @setSharedState(WAVE_SHARED_STATE_PUBLIC, @_publicRoleId) if @_isPublicButton.checked
        @_sharedRoleSelect = $(@_sharePopup).find('.js-shared-role-select')[0]

        setPopup = (node, getRole, setRole) =>
            $(node).click (event) =>
                return if not @_canChangeTopicShare
                popup.hide()
                popup.render(new RoleSelectPopup(DEFAULT_ROLES, getRole, setRole), event.target)
                popup.show()
                return false
        getRole = => @_byLinkRoleId
        setRole = (roleId) =>
            @_byLinkRoleId = roleId
            popup.hide()
            @setSharedState(WAVE_SHARED_STATE_LINK_PUBLIC, @_byLinkRoleId)
        setPopup(@_sharedRoleSelect, getRole, setRole)
        getRole = => @_publicRoleId
        setRole = (roleId) =>
            @_publicRoleId = roleId
            popup.hide()
            @setSharedState(WAVE_SHARED_STATE_PUBLIC, @_publicRoleId)
        @_publicRoleSelect = $(@_sharePopup).find('.js-public-role-select')[0]
        for [roleId, roleName] in DEFAULT_ROLES
            $(@_publicRoleSelect).text(roleName) if roleId is @_publicRoleId
        setPopup(@_publicRoleSelect, getRole, setRole)
        @_initSocialShareButtons()
        @updatePublicState()

    _disableSocialButtons: ->
        @_socialOverlay.addClass('social-overlay')
        @_facebookButton.attr('disabled', 'disabled')
        @_twitterButton.attr('disabled', 'disabled')
        @_googleButton.attr('disabled', 'disabled')

    _enableSocialButtons: ->
        @_socialOverlay.removeClass('social-overlay')
        @_facebookButton.removeAttr('disabled')
        @_twitterButton.removeAttr('disabled')
        @_googleButton.removeAttr('disabled')

    _setShareContainerClass: (className) ->
        $(@_shareContainer).removeClass('private')
        $(@_shareContainer).removeClass('public')
        $(@_shareContainer).removeClass('shared')
        $(@_shareContainer).addClass(className)

    _setDefaultRoleId: (element, roleId) ->
        for [id, name] in DEFAULT_ROLES
            continue if roleId isnt id
            $(element).text(name)

    __scrollToBlipContainer: (blipContainer) ->
        DOM.scrollTargetIntoViewWithAnimation(blipContainer, @_waveBlips, yes, SCROLL_INTO_VIEW_OFFSET)

    updatePublicState: (sharedState = @_model.getSharedState(), defaultRoleId = @_model.getDefaultRole()) ->
        ###
        Устанавливает состояние переключателя публичности волны
        @param isPublic: boolean
        @param defaultRoleId: int
        ###
        return if not window.loggedIn
        if sharedState == WAVE_SHARED_STATE_LINK_PUBLIC
            @_isByLinkButton.checked = true
            @_setDefaultRoleId(@_sharedRoleSelect, defaultRoleId)
            @_byLinkRoleId = defaultRoleId
            @_setShareContainerClass('shared')
            @_enableSocialButtons()
            @_shareButton.attr('title', "Topic is shared by link, click to change")
            @_participants.showCreateTopicForSelectedButton()
        else if sharedState == WAVE_SHARED_STATE_PRIVATE
            @_isPrivateButton.checked = true
            @_setShareContainerClass('private')
            @_disableSocialButtons()
            @_shareButton.attr('title', "Topic is private, click to change")
            @_participants.showCreateTopicForSelectedButton()
        else
            @_isPublicButton.checked = true
            @_setDefaultRoleId(@_publicRoleSelect, defaultRoleId)
            @_publicRoleId = defaultRoleId
            @_setShareContainerClass('public')
            @_enableSocialButtons()
            @_shareButton.attr('title', "Topic is public, click to change")
            @_participants.hideCreateTopicForSelectedButton()
        @_shareContainerWidth = $(@_shareContainer).width() +
            parseInt($(@_shareContainer).css('margin-left')) +
            parseInt($(@_shareContainer).css('margin-right'))
        return if @_waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR]
        @_updateParticipantsManagement()

    setSharedState: (sharedState, defaultRole=1) ->
        ###
        Устанавливает публичность волны
        Обновляет кнопку в интерфейсе и отправляет команду серверу при необходимости
        @param isPublic: boolean
        @param defaultRole: int
        ###
        @updatePublicState(sharedState, defaultRole)
        @_waveProcessor.setWaveShareState @_model.serverId, sharedState, defaultRole, (err) =>
            if @_isPublicButton.checked
                _gaq.push(['_trackEvent', 'Topic sharing', 'Set topic public'])
            else if @_isPrivateButton.checked
                _gaq.push(['_trackEvent', 'Topic sharing', 'Set topic private'])
            else
                _gaq.push(['_trackEvent', 'Topic sharing', 'Set topic shared'])
            return if not err
            @_waveViewModel.showWarning(err.message)
            @updatePublicState()

    _initParticipants: (waveViewModel, participants) ->
        ###
        Инициализирует панель с участниками волны
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        ###
        @_participants = new Participants(waveViewModel, @_waveProcessor, @_model.serverId,
                participants, yes, @_model.getGDriveShareUrl())
        $(@container).find('.js-wave-participants').append(@_participants.getContainer())
        @_excludeParticipantsWidth = 0
        headerChildren = $(@_waveHeader).children()
        for child in headerChildren
            if $(child).hasClass('js-wave-participants') or $(child).hasClass('clearer') or not $(child).is(':visible')
                continue
            @_excludeParticipantsWidth += $(child).outerWidth(true)
        @_setParticipantsWidth()
        $(window).on 'resize resizeTopicByResizer', @_setParticipantsWidth #resizeTopicByResizer срабатывает при изменении ширины ресайзером

    getParticipantIds: ->
        @_participants.all()

    _setParticipantsWidth: () =>
        if @_isAnonymous
            participantsWidth = $(@container).find('.js-wave-participants').outerWidth()
        else
            headerInnerWidth = $(@_waveHeader).width() -
                parseInt($(@_waveHeader).css('padding-left')) -
                parseInt($(@_waveHeader).css('padding-right'))
            participantsWidth = headerInnerWidth - @_excludeParticipantsWidth -
                parseInt($($(@_waveHeader).find('.js-participant-container')[0]).css('margin-left')) -
                parseInt($($(@_waveHeader).find('.js-participant-container')[0]).css('margin-right'))
            participantsWidth -= @_reservedHeaderSpace
        @_participants.setParticipantsWidth(participantsWidth)

    _initEditingMenu: ->
        ###
        Инициализирует меню редактирования волны
        ###
        return if not @_editable
        @_initEditingMenuKeyHandlers()
        @_disableEditingButtons()
        @_disableActiveBlipControls()
        @_initActiveBlipControls()

    _initActiveBlipControls: ->
        ###
        Инициализирует кнопки вставки реплая или меншена в активный блиб
        ###
        checkPermission = (callback) => (args...) =>
            return false if @_activeBlipControlsEnabled is no
            callback(args...)

        activateButtons = (buttons) =>
            for controlInfo in buttons
                {className, handler} = controlInfo
                controlInfo.$button = @_$activeBlipControls.find(className)
                controlInfo.$button.mousedown(handler)

        @_activeBlipControlButtons = [
            {className: '.js-insert-reply', handler: checkPermission(@_eventHandler(@_insertBlipButtonClick))}
            {className: '.js-insert-mention', handler: checkPermission(@_eventHandler(@_insertMention))}
            {className: '.js-insert-tag', handler: checkPermission(@_eventHandler(@_insertTag))}
            {className: '.js-insert-gadget', handler: checkPermission(@_eventHandler(@_showGadgetPopup))}
        ]
        activateButtons(@_activeBlipControlButtons)

        accountProcessor = require('../account_setup_wizard/processor').instance
        businessButtons = [{className: '.js-insert-task', handler: checkPermission(@_eventHandler(@_insertTask))}]
        if accountProcessor.isBusinessUser()
            activateButtons(businessButtons)
            @_activeBlipControlButtons.push(businessButtons[0])
        else
            $insertTaskBtn = @_$activeBlipControls.find('.js-insert-task').hide()
            businessChangeCallback = (isBusiness) =>
                return unless isBusiness
                return unless @_activeBlipControlButtons
                $insertTaskBtn.show()
                accountProcessor.removeListener('is-business-change', businessChangeCallback)
                activateButtons(businessButtons)
                @_activeBlipControlButtons.push(businessButtons[0])

            accountProcessor.on('is-business-change', businessChangeCallback)

    _deinitActiveBlipControls: ->
        for {$button, handler} in @_activeBlipControlButtons
            $button?.off('mousedown', handler)
        delete @_activeBlipControlButtons

    _initEditingMenuKeyHandlers: ->
        ###
        Инициализирует обработчики нажатий на клавиши в топике
        ###
        @_ctrlHandlers =
            65: @_selectAll        # A
            69: @_changeBlipEditMode # e

        @_globalCtrlHandlers =
            32: @_goToUnread        # Space

        @_ctrlShiftHandlers =
            38: @_foldChildBlips    # Up arrow
            40: @_unfoldChildBlips  # Down arrow

        @_shiftHandlers =
            13: @_setBlipReadMode   # Enter

        @_ctrlRepeats = {}
        @blipNode.addEventListener('keydown', @_preProcessKeyDownEvent, true)
        @blipNode.addEventListener('keypress', @_processFFEnterKeypress, true) if BrowserSupport.isMozilla()
        @_globalKeyHandler = (e) =>
            return if not (e.ctrlKey or e.metaKey)
            @_processKeyDownEvent(@_globalCtrlHandlers, e)
        window.addEventListener('keydown', @_globalKeyHandler, true)
        @blipNode.addEventListener('keyup', @_processBlipKeyUpEvent, true)
        @blipNode.addEventListener('click', @_processClickEvent, false) if BrowserSupport.isSupported()

    _changeBlipEditMode: =>
        blip = @_getBlipAndRange()[0]
        return if not blip
        blip.setEditable(!@_inEditMode)

    _processFFEnterKeypress: (e) =>
        # превентим keypress у Enter для ff, чтобы при завершении
        # режима редактирования по Shift+Enter не создавался новый блип
        return if e.keyCode != 13 or !e.shiftKey
        e.stopPropagation()

    _setBlipReadMode: (e) =>
        blip = @_getBlipAndRange()[0]
        return if not blip
        blip.setEditable(no)

    _initRootBlip: (waveViewModel) ->
        ###
        Инициализирует корневой блип
        ###
        processor = require('../blip/processor').instance
        processor.openBlip waveViewModel, @_model.getContainerBlipId(), @blipNode, null, @_onRootBlipGot
        @on 'range-change', (range, blip) =>
            if blip
                @markActiveBlip(blip)

    _onRootBlipGot: (err, @rootBlip) =>
        return @_waveProcessor.showPageError(err) if err
        @_initRangeChangeEvent()

    _disableEditingButtons: -> @_editingButtonsEnabled = no

    _enableEditingButtons: -> @_editingButtonsEnabled = yes

    _disableActiveBlipControls: ->
        return if not @_editable
        return if @_activeBlipControlsEnabled is no
        @_activeBlipControlsEnabled = no
        @_hideGadgetPopup()
        @_$activeBlipControls.addClass('unvisible')

    enableActiveBlipControls: ->
        # Показ меню делаем на следующей итерации, чтобы меню сначала спряталось
        # остальными топиками, а затем показалось этим
        window.setTimeout =>
            return if @_activeBlipControlsEnabled is yes
            @_activeBlipControlsEnabled = yes
            @_$activeBlipControls.removeClass('unvisible')
        , 0

    cursorIsInText: -> @_editingButtonsEnabled

    _checkChangedRange: (range, blipView) ->
        if range
            DOM.addClass(@container, 'has-cursor')
        else
            DOM.removeClass(@container, 'has-cursor')
        if range and blipView.getPermission() in [EDIT_PERMISSION, COMMENT_PERMISSION]
            if @_inEditMode
                @enableActiveBlipControls()
            else
                @_disableActiveBlipControls()
            if blipView.getPermission() is EDIT_PERMISSION
                @_enableEditingButtons()
            else
                @_disableEditingButtons()
        else
            @_disableEditingButtons()
            @_disableActiveBlipControls()
        if blipView is @_lastBlip
            return if range is @_lastRange
            return if range and @_lastRange and
                range.compareBoundaryPoints(Range.START_TO_START, @_lastRange) is 0 and
                range.compareBoundaryPoints(Range.END_TO_END, @_lastRange) is 0
        @_lastRange = range
        @_lastRange = @_lastRange.cloneRange() if @_lastRange
        @_lastBlip = blipView
        @emit('range-change', @_lastRange, blipView)

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

    _windowCheckCusor: (e) =>
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
        window.addEventListener('mousedown', @_windowCheckCusor, no)
        window.addEventListener('mouseup', @_windowCheckCusor, no)

    _eventHandler: (func) ->
        ###
        Возвращает функцию, которая остановит событие и вызовет переданную
        @param func: function
        @return: function
            function(event)
        ###
        (event) ->
            event.preventDefault()
            event.stopPropagation()
            func(event)

    _createDOM: (renderWave) ->
        ###
        Создает DOM для отображения документа
        ###
        c = $(@container)
        BrowserEvents.addPropagationBlocker(@container, BrowserEvents.DOM_NODE_INSERTED) # TODO: find better place
        c.empty()
        waveParams =
            url: @getUrl()
            editable: @_editable
            isAnonymous: @_isAnonymous
            gDriveShareUrl: @_model.getGDriveShareUrl()
            isGDriveView: History.isGDrive()
        c.append renderWave(waveParams)
        @_waveContent = $(@container).find('.js-wave-content')[0]
        @_waveBlips = $(@container).find('.js-wave-blips')[0]
        @_$activeBlipControls = $('.js-right-tools-panel .js-active-blip-controls')
        @blipNode = $(@container).find('.js-container-blip')[0]

    _initSettingsMenu: ->
        menu = new SettingsMenu()
        $settingsContainer = $(@container).find('.js-settings-container')
        $settingsContainer.on BrowserEvents.C_READ_ALL_EVENT, =>
            @emit(@constructor.Events.READ_ALL)
        menu.render($settingsContainer[0],
            topicId: @_waveViewModel.getServerId()
            exportUrl: @getExportUrl()
            embeddedUrl: @_getEmbeddedUrl()
        )
        
    _initAccountMenu: ->
        menu = new AccountMenu()
        menu.render($('.js-account-container')[0],
            role: @_getRole()
        )

    markActiveBlip: (blip) =>
        ###
        @param blip: BlipView
        ###
        # TODO: work with BlipViewModel only
        return blip.updateCursor() if @_activeBlip is blip
        if @_activeBlip
            @_activeBlip.clearCursor()
            @_activeBlip.unmarkActive()
        @_activeBlip = blip
        @_activeBlip.setCursor()
        @_activeBlip.markActive()
        @_activeBlip.setReadState(true)
        @_model.setActiveBlip(blip.getViewModel())
        @_setOnScrollMenuPosition()

    _resizerRepositionMenu: =>
        RangeMenu.get().hide()
        @_activeBlip?.updateMenuLeftPosition()

    _setOnScrollMenuPosition: (e = false) =>
        RangeMenu.get().hide()
        @_activeBlip?.updateMenuPosition(e)

    _isExistParticipant: (email) =>
        participants = @_waveViewModel.getUsers(@_participants.all())
        for p in participants
            if p.getEmail() == email
                return true
        false

    _processAddParticipantClick: =>
        ###
        Обрабатывает нажатие на кнопку добавления участника
        ###
        email = strip(@_$participantIdInput.val())
        return if not email
        if not isEmail(email)
            return @_waveViewModel.showWarning("Enter valid e-mail")
        if @_isExistParticipant(email)
            @_waveViewModel.showWarning("Participant already added to topic")
            @_$participantIdInput.select()
            return
        @_waveProcessor.addParticipant(@_model.serverId, email, @_addButtonRole, @_processAddParticipantResponse)
        @_$participantIdInput.val('').focus()

    _processAddParticipantResponse: (err, user) =>
        ###
        Обрабатывает ответ сервера на добавление пользователя
        @param err: object|null
        ###
        return @_waveViewModel.showWarning(err.message) if err
        $(@container).parent('.js-inner-wave-container').find('.js-wave-notifications .js-wave-warning').remove()
        trackParticipantAddition('By email field', user)
        @_waveViewModel.updateUserInfo(user)
        @_waveProcessor.addOrUpdateContact(user)
        @_addParticipantForm?.restartAutocompleter()

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
        commonView?.getEditor().focus()
        return [commonView, range]

    _getBlipAndRange: ->
        ###
        Возвращает текущее выделение и блип, в котором оно сделано
        @return: [BlipView, DOM range]|null
        ###
        return null if not @rootBlip
        selection = window.getSelection()
        return if not selection or not selection.rangeCount
        range = selection.getRangeAt(0)
        return null if not range
        cursor = [range.startContainer, range.startOffset]
        blipViewStart = @rootBlip.getView().getBlipContainingCursor(cursor)
        directionForward = if selection.anchorNode is range.startContainer and selection.anchorOffset is range.startOffset then yes else no
        unless blipViewStart
#            selection.removeAllRanges()
            return null
        cursor = [range.endContainer, range.endOffset]
        blipViewEnd = if range.collapsed then blipViewStart else @rootBlip.getView().getBlipContainingCursor(cursor)
        if blipViewStart isnt blipViewEnd
            return @_expandCrossedBlipRange(range, blipViewStart, blipViewEnd, directionForward)
        else if blipViewStart isnt @_lastBlip
            editor = blipViewStart.getEditor()
            editor.focus()
        return [blipViewStart, range]

    # TODO: remove it
    _createBlip: (forceCreate=false) ->
        ###
        @param: forceCreate boolean
        @return: BlipViewModel | undefined
        ###
        opParams = @_getBlipAndRange()
        return if not opParams
        [blip] = opParams
        if not @_inEditMode or forceCreate
            blipViewModel = blip.initInsertInlineBlip()
            return if not blipViewModel
            return blipViewModel

    _insertBlipButtonClick: =>
        blipViewModel = @_createBlip(true)
        return if not blipViewModel
        _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Re in editing menu'])

    _insertMention: =>
        blipViewModel = @_createBlip()
        blipView = if not blipViewModel then @_activeBlip else blipViewModel.getView()
        return if not blipView
        setTimeout ->
            recipientInput = blipView.getEditor().insertRecipient()
            recipientInput?.insertionEventLabel = 'Menu button'
        , 0

    _insertTag: =>
        blipViewModel = @_createBlip()
        blipView = if not blipViewModel then @_activeBlip else blipViewModel.getView()
        return if not blipView
        setTimeout ->
            tagInput = blipView.getEditor().insertTag()
            tagInput?.insertionEventLabel = 'Menu button'
        , 0

    _insertTask: =>
        blipViewModel = @_createBlip()
        blipView = if not blipViewModel then @_activeBlip else blipViewModel.getView()
        return if not blipView
        setTimeout ->
            taskInput = blipView.getEditor().insertTaskRecipient()
            taskInput?.insertionEventLabel = 'Menu button'
        , 0

    _showGadgetPopup: (event) =>
        if event.ctrlKey and event.shiftKey
            @_insertGadget()
        else
            gadgetPopup = @getInsertGadgetPopup()
            if gadgetPopup.isVisible()
                @_hideGadgetPopup()
            else
                gadgetPopup.show(@getActiveBlip())
                gadgetPopup.shownAt = Date.now()

    _hideGadgetPopup: ->
        gadgetPopup = @getInsertGadgetPopup()
        return if not gadgetPopup?
        shouldHide = true
        if gadgetPopup.shownAt?
            timeDiff = Date.now() - gadgetPopup.shownAt
            shouldHide = timeDiff > 100
            # Не скрываем popup, если после открытия прошло меньше 100 мс. Нужно, чтобы несколько топиков не
            # мешали друг другу
        gadgetPopup.hide() if shouldHide

    getInsertGadgetPopup: ->
        if not @_insertGadgetPopup and @_activeBlipControlButtons
            for control in @_activeBlipControlButtons when control.className is '.js-insert-gadget'
                @_insertGadgetPopup = control.$button[0].insertGadgetPopup
        return @_insertGadgetPopup
    
    _insertGadget: =>
        opParams = @_getBlipAndRange()
        return if not opParams
        [blip, range] = opParams
        blip.initInsertGadget()

    _foldChildBlips: =>
        ###
        Сворачивает все блипы, вложенные в текщуий
        ###
        @_ctrlRepeats.foldChildBlips ?= 0
        if @_ctrlRepeats.foldChildBlips
            blip = @rootBlip.getView()
            blip.foldAllChildBlips()
            blip.setCursorToStart()
            @_checkRange()
        else
            r = @_getBlipAndRange()
            return if not r
            [blip] = r
            blip.foldAllChildBlips()
        if blip is @rootBlip.getView()
            _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Root shortcut'])
        else
            _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Reply shortcut'])
        @_ctrlRepeats.foldChildBlips++

    _unfoldChildBlips: =>
        ###
        Разворачивает все блипы, вложенные в текщуий
        ###
        @_ctrlRepeats.foldChildBlips = 0
        r = @_getBlipAndRange()
        return if not r
        [blip] = r
        if blip is @rootBlip.getView()
            _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Root shortcut'])
        else
            _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Reply shortcut'])
        blip.unfoldAllChildBlips()

    _selectAll: =>
        ###
        Выделяет все содержимое блипа, при двукратном нажатии - все содержимое корневого тредового блипа
        ###
        @_ctrlRepeats.selectAll ?= 0
        if @_ctrlRepeats.selectAll
            blips = @rootBlip.getView().getChildBlips()
            blip = null
            r = DOM.getRange()
            return if not r
            node = r.startContainer
            for own _, b of blips
                bView = b.getView()
                bContainer = bView.getContainer()
                if DOM.contains(bContainer, node) or bContainer is node
                    blip = bView
                    break
            return if not blip
        else
            r = @_getBlipAndRange()
            return if not r
            [blip] = r
        @_ctrlRepeats.selectAll++
        range = blip.selectAll()
        @_checkChangedRange(range, blip)

    _goToUnread: =>
        ###
        Переводит фокус на первый непрочитаный блип,
        расположенный после блипа под фокусом
        ###
        return if @_curView isnt 'text'
        @emit('goToNextUnread')

    getActiveBlip: ->
        #TODO: hack activeBlip
        @_activeBlip.getViewModel()

    getRootBlip: ->
        @rootBlip

    updateRangePos: ->
        @_setOrUpdateRangeMenuPos(yes)

    _setOrUpdateRangeMenuPos: (update) ->
        menu = RangeMenu.get()
        return menu.hide() if not @_lastBlip or not @_lastRange
        return menu.hide() unless BrowserSupport.isSupported()
        if update
            @_lastBlip.updateRangeMenuPosByRange(@_lastRange, @container)
        else
            @_lastBlip.setRangeMenuPosByRange(@_lastRange, @container)

    _preProcessKeyDownEvent: (e) =>
        if e.ctrlKey or e.metaKey
            handlers = @_ctrlHandlers
            if e.shiftKey
                handlers = @_ctrlShiftHandlers
        else if e.shiftKey
            handlers = @_shiftHandlers
        @_processKeyDownEvent(handlers, e)

    _processKeyDownEvent: (handlers, e) =>
        ###
        Обрабатывает нажатия клавиш внутри блипов
        @param e: DOM event
        ###
        return if ((not (e.ctrlKey or e.metaKey)) and (not e.shiftKey)) or e.altKey
        return if not (e.keyCode of handlers)
        handlers[e.keyCode]()
        e.preventDefault()
        e.stopPropagation()

    _processBlipKeyUpEvent: (e) =>
        ###
        Обрабатывает отпускание клавиш внутри блипов
        @param e: DOM event
        ###
        return if e.which != 17 or e.keyCode != 17
        # Обрабатываем только отпускание ctrl
        @_ctrlRepeats = {}

    _removeAutocompleter: ->
        @_autoCompleter?.deactivate()
        @_autoCompleter?.dom.$results.remove()
        delete @_autoCompleter

    _processClickEvent: =>
        @_setOrUpdateRangeMenuPos(no)

    destroy: ->
        super()
        # TODO: move it to another function
        delete @_ctrlHandlers
        delete @_ctrlShiftHandlers
        delete @_shiftHandlers
        delete @_globalCtrlHandlers
        window.removeEventListener 'keydown', @_globalKeyHandler, true
        delete @_globalKeyHandler

        LocalStorage.removeListener('buffer', @_handleBufferUpdate)
        @_closed = true
        @_$addButtonSelect?.selectBox('destroy')
        @_addParticipantForm?.destroy()
        delete @_insertGadgetPopup
        @_participants.destroy()
        delete @_participants
        @_destroySavingMessage()
        require('../editor/file/upload_form').removeInstance()
        @removeListeners('range-change')
        @removeAllListeners()
        $(@_waveBlips).off 'scroll'
        $(window).off('scroll', @_setOnScrollMenuPosition)
        @blipNode.removeEventListener 'keydown', @_preProcessKeyDownEvent, true
        @blipNode.removeEventListener('keypress', @_processFFEnterKeypress, true) if BrowserSupport.isMozilla()
        @blipNode.removeEventListener 'keyup', @_processBlipKeyUpEvent, true
        @blipNode.removeEventListener('click', @_processClickEvent, false)
        delete @blipNode
        window.removeEventListener 'keydown', @runCheckRange, false
        window.removeEventListener('mousedown', @_windowCheckCusor, no)
        window.removeEventListener('mouseup', @_windowCheckCusor, no)
        $wnd = $(window)
        $wnd.off('resize resizeTopicByResizer', @_setParticipantsWidth)
        $wnd.off('resize resizeTopicByResizer', @_resizerRepositionMenu)
        @_destroyMindmap()
        @_removeAutocompleter()
        $(@container).empty().unbind()
        @_disableActiveBlipControls()
        @_deinitActiveBlipControls()
        delete @rootBlip
        delete @_activeBlip if @_activeBlip
        delete @_editingBlip if @_editingBlip
        delete @_lastBlip if @_lastBlip
        delete @_lastEditableBlip if @_lastEditableBlip
        @_destroyDragScroll()
        @container = undefined
        delete @_model
        delete @_waveViewModel
        # hack - clean jQuery's cached fragments
        jQuery.fragments = {}

    applyParticipantOp: (op) ->
        @_participants.applyOp(op)
        return if not window.loggedIn
        isMyOp = op.ld?.id is window.userInfo.id or op.li?.id is window.userInfo.id
        return if not isMyOp
        @updateInterfaceAccordingToRole()

    updateInterfaceAccordingToRole: ->
        @_waveViewModel.updateParticipants()
        @_updateParticipantsManagement()
        @rootBlip.getView().recursivelyUpdatePermission()
        @_updateReplyButtonState()

    _updateReplyButtonState: ->
        ###
        Ставится или снимается класс, прячущий кнопки реплаев
        ###
        if @_waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR, ROLE_COMMENTATOR]
            $(@container).removeClass('read-only')
            @_canReply = true
        else
            $(@container).addClass('read-only')
            @_canReply = false

    _updateParticipantsManagement: ->
        ###
        Приводит окна управления пользователей в состояние, соответствующее текущим правам
        ###
        @_updateParticipantAddition()
        @_updateWaveSharing()

    _updateParticipantAddition: ->
        myRole = @_waveViewModel.getRole()
        if myRole is ROLE_NO_ROLE
            @_$addButton?.attr('disabled', 'disabled')
        else
            @_$addButton?.removeAttr('disabled')
            if @_model.getSharedState() is WAVE_SHARED_STATE_PRIVATE
                defaultRole = myRole
                defaultRole = ROLE_EDITOR if defaultRole is ROLE_OWNER
                @_addButtonRole = defaultRole
                @_$addButtonSelect?.selectBox('value', defaultRole)
            else
                @_addButtonRole = @_model.getDefaultRole()
                @_$addButtonSelect?.selectBox('value', @_model.getDefaultRole())
        if (myRole in [ROLE_OWNER, ROLE_EDITOR])
            @_$addButtonSelect?.selectBox('enable')
        else
            @_$addButtonSelect?.selectBox('disable')

    _updateWaveSharing: ->
        if (@_waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR])
            $([@_isPrivateButton, @_isByLinkButton, @_isPublicButton]).removeAttr('disabled')
            $([@_publicRoleSelect, @_sharedRoleSelect]).removeClass('disabled')
            @_canChangeTopicShare = true
        else
            $([@_isPrivateButton, @_isByLinkButton, @_isPublicButton]).attr('disabled', 'disabled') if @_isPrivateButton or @_isByLinkButton or @_isPublicButton
            $([@_publicRoleSelect, @_sharedRoleSelect]).addClass('disabled') if @_publicRoleSelect or @_sharedRoleSelect
            @_canChangeTopicShare = false

    isExistParticipant: (email) ->
        @_isExistParticipant(email)

    processAddParticipantResponse: (err, user) =>
        @_processAddParticipantResponse(err, user)

    getUrl: ->
        ###
        Возвращает ссылку, соответствующую волне
        @return: string
        ###
        return "#{document.location.protocol}//#{window.HOST + History.getWavePrefix()}#{@_model.serverId}/"

    getExportUrl: ->
        return "/api/export/1/#{@_model.serverId}/html/"

    _getEmbeddedUrl: ->
        "#{document.location.protocol}//#{window.HOST + History.getEmbeddedPrefix()}#{@_model.serverId}/"

    getSocialSharingUrl: ->
        ###
        Возвращает ссылку для шаринга волны в соцсетях
        @return: string
        ###
        return document.location.protocol + '//' +
            window.HOST +
            window.socialSharingConf.url +
            @_model.serverId +
            @_model.socialSharingUrl.substr(0, window.socialSharingConf.signLength) +
            "/#{randomString(2)}"

    _initTips: ->
        @_$topicTipsContainer = $(@container).find('.js-topic-tip')
        @_$topicTipsContainer.find('.js-hide-topic-tip').click(@_hideTip)
        @_$topicTipsContainer.find('.js-next-tip').click(@_showNextTip)

    _tipIsHidden: ->
        return true if not LocalStorage.loginCountIsMoreThanTwo()
        lastHiddenDate = LocalStorage.getLastHiddenTipDate() - 0
        return @_lastTipDate <= lastHiddenDate

    showTip: (text, @_lastTipDate, force=false) ->
        return if not force and @_tipIsHidden()
        LocalStorage.removeLastHiddenTipDate() if force
        $textContainer = @_$topicTipsContainer.find('.js-topic-tip-text')
        $textContainer.html(text).find('a').attr('target', '_blank')
        $textContainer.attr('title', $textContainer.text())
        $(@container).addClass('tip-shown')

    _hideTip: =>
        _gaq.push(['_trackEvent', 'Tips', 'Close tip'])
        LocalStorage.setLastHiddenTipDate(@_lastTipDate)
        $(@container).removeClass('tip-shown')

    _showNextTip: =>
        _gaq.push(['_trackEvent', 'Tips', 'Show next tip'])
        @_waveProcessor.showNextTip()

    setTextView: =>
        return if @_curView is 'text'
        @_curView = 'text'
        $(@_waveContent).removeClass('mindmap-view')
        @emit('wave-view-change')

    setMindmapView: =>
        return if @_curView is 'mindmap'
        @_curView = 'mindmap'
        $(@_waveContent).addClass('mindmap-view')
        _gaq.push(['_trackEvent', 'Topic content', 'Switch to mindmap'])
        if not @_mindmap?
            @_initMindmap()
        else
            @_mindmap.update()
        @emit('wave-view-change')

    setShortMindmapView: =>
        @_mindmap?.setShortMode()

    setLongMindmapView: =>
        @_mindmap?.setLongMode()

    getCurView: -> @_curView

    getScrollableElement: -> @_waveBlips

    _initMindmap: ->
        @_mindmap = new MindMap(@_waveViewModel)
        mindMapContainer = $(@container).find('.js-topic-mindmap-container')[0]
        @_mindmap.render(mindMapContainer)

    _destroyMindmap: ->
        @_mindmap?.destroy()
        delete @_mindmap

    _initDragScroll: ->
        @_resetDragScrollVars()
        @container.addEventListener('dragenter', @_handleContainerDragEnterEvent, no)
        @container.addEventListener('dragleave', @_handleContainerDragLeaveEvent, no)
        @container.addEventListener('drop', @_handleContainerDropEvent, no)
        for el in @container.getElementsByClassName('js-scroll')
            el.addEventListener('dragenter', @_handleScrollDragEnterEvent, no)
            el.addEventListener('dragleave', @_handleScrollDragLeaveEvent, no)
        @_scrollUpEl = @container.getElementsByClassName('js-scroll-up')[0]
        @_scrollDownEl = @container.getElementsByClassName('js-scroll-down')[0]

    _destroyDragScroll: ->
        @_resetDragScrollVars()
        @container.removeEventListener('dragenter', @_handleContainerDragEnterEvent, no)
        @container.removeEventListener('dragleave', @_handleContainerDragLeaveEvent, no)
        @container.removeEventListener('drop', @_handleContainerDropEvent, no)
        for el in @container.getElementsByClassName('js-scroll')
            el.removeEventListener('dragenter', @_handleScrollDragEnterEvent, no)
            el.removeEventListener('dragleave', @_handleScrollDragLeaveEvent, no)
        @_handleContainerDragEnterEvent = undefined
        @_handleContainerDragLeaveEvent = undefined
        @_handleContainerDropEvent = undefined
        @_handleScrollDragEnterEvent = undefined
        @_handleScrollDragLeaveEvent = undefined
        @_doScrollOnDrag = undefined
        @_scrollUpEl = undefined
        @_scrollDownEl = undefined

    _handleContainerDragEnterEvent: =>
        @_dragCount++
        @_updateDragState()

    _handleContainerDragLeaveEvent: =>
        @_dragCount--
        @_updateDragState()

    _handleContainerDropEvent: =>
        @_resetDragScrollVars()
        @_updateDragState()

    _handleScrollDragEnterEvent: (e) =>
        @_lastDraggedOverClass = e.target.className
        @_dragScrollAmount = parseInt(e.target.getAttribute('offset')) || 0
        @_setDragScrollInterval() if @_dragScrollAmount

    _handleScrollDragLeaveEvent: (e) =>
        if e.target.className is @_lastDraggedOverClass
            @_lastDraggedOverClass = ''
            @_clearDragScrollInterval()

    _resetDragScrollVars: ->
        @_clearDragScrollInterval()
        @_dragScrollAmount = 0
        @_dragCount = 0
        @_lastDraggedOverClass = ''

    _setDragScrollInterval: ->
        @_clearDragScrollInterval()
        @_dragScrollIntervalId = setInterval(@_doScrollOnDrag, 100)

    _doScrollOnDrag: =>
        scrollTop = @_waveBlips.scrollTop
        scrollHeight = @_waveBlips.scrollHeight
        height = @_waveBlips.offsetHeight
        if scrollTop + @_dragScrollAmount <= 0
            @_waveBlips.scrollTop = 0
            @_clearDragScrollInterval()
            return @_updateDragState()
        if scrollTop + height + @_dragScrollAmount >= scrollHeight
            @_waveBlips.scrollTop = scrollHeight - height
            @_clearDragScrollInterval()
            return @_updateDragState()
        @_waveBlips.scrollTop += @_dragScrollAmount

    _clearDragScrollInterval: ->
        return unless @_dragScrollIntervalId
        @_dragScrollIntervalId = clearInterval(@_dragScrollIntervalId)

    _updateTopScrollArea: (show) ->
        if show
            @_scrollUpEl.style.display = 'block'
        else
            @_scrollUpEl.style.display = 'none'

    _updateBottomScrollArea: (show) ->
        if show
            @_scrollDownEl.style.display = 'block'
        else
            @_scrollDownEl.style.display = 'none'

    _showScrollableAreas: ->
        height = @_waveBlips.offsetHeight
        scrollHeight = @_waveBlips.scrollHeight
        return @_hideScrollableAreas() if height is scrollHeight
        scrollTop = @_waveBlips.scrollTop
        unless scrollTop
            @_updateTopScrollArea(no)
        else
            @_updateTopScrollArea(yes)
        if scrollTop + height >= scrollHeight
            @_updateBottomScrollArea(no)
        else
            @_updateBottomScrollArea(yes)

    _hideScrollableAreas: ->
        @_updateTopScrollArea(no)
        @_updateBottomScrollArea(no)

    _updateDragState: ->
        if @_dragCount
            @_showScrollableAreas()
        else
            @_hideScrollableAreas()
        
    _initSavingMessage: ->
        @_savingMessage = new SavingMessageView()
        @_savingMessage.init(@_waveViewModel.getId(), @_waveHeader)
        
    _destroySavingMessage: ->
        @_savingMessage?.destroy()
        delete @_savingMessage

    _setEditMode: (@_inEditMode) ->
        cl = 'wave-edit-mode'
        if @_inEditMode then DOM.addClass(@_container, cl) else DOM.removeClass(@_container, cl)
        @_checkChangedRange(@_lastRange, @_lastBlip) # show/hide controls # TODO: is it good?

    hasCursor: ->
        DOM.hasClass(@container, 'has-cursor')

    setEditModeEnabled: (enabled) -> @_setEditMode(enabled)

    isEditMode: -> @_inEditMode

    getContainer: -> @container
    
    foldAll: ->
        if @_curView is 'text'
            @rootBlip.getView().foldAllChildBlips()
        else
            @_mindmap.fold()

    unfoldAll: ->
        if @_curView is 'text'
            @rootBlip.getView().unfoldAllChildBlips()
        else
            @_mindmap.unfold()

    _initBuffer: ->
        LocalStorage.on('buffer', @_handleBufferUpdate)
        @_updateBufferPresenceMark(LocalStorage.hasBuffer())

    _updateBufferPresenceMark: (hasBuffer) ->
        if hasBuffer
            $(@container).addClass('has-buffer')
        else
            $(@container).removeClass('has-buffer')

    _handleBufferUpdate: (param) =>
        @_updateBufferPresenceMark(param.newValue?)

    setReservedHeaderSpace: (@_reservedHeaderSpace) ->
        @_setParticipantsWidth()

class SavingMessageView

    SAVE_TIME: 0.5
    FADE_TIME: 120
    
    constructor: ->
        @_saveTimeout = null
        @_fadeTimeout = null
    
    _getMessages: ->
        container = $(@_container)
        return [container.find('.js-saving-message-saving'), container.find('.js-saving-message-saved')]
    
    _onStartSend: (groupId) =>
        return if groupId isnt @_waveId
        [saving, saved] = @_getMessages()
        saved.removeClass('visible')
        saving.addClass('visible')
            
    _onFinishSend: (groupId) =>
        clearTimeout(@_saveTimeout) if @_saveTimeout
        @_saveTimeout = setTimeout =>
            return if groupId isnt @_waveId
            [saving, saved] = @_getMessages()
            saving.removeClass('visible')
            saved.addClass('visible')
            clearTimeout(@_fadeTimeout) if @_fadeTimeout
            @_fadeTimeout = setTimeout ->
                saved.removeClass('visible')
            , @FADE_TIME * 1000
        , @SAVE_TIME * 1000

    init: (@_waveId, @_container) ->
        processor = require('../ot/processor').instance
        processor.on('start-send', @_onStartSend)
        processor.on('finish-send', @_onFinishSend)

    destroy: ->
        processor = require('../ot/processor').instance
        processor.removeListener('start-send', @_onStartSend)
        processor.removeListener('finish-send', @_onFinishSend)
        clearTimeout(@_saveTimeout)
        clearTimeout(@_fadeTimeout)

module.exports = WaveView: WaveView
