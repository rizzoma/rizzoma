BlipViewBase = require('./view_base')
{EDIT_PERMISSION, COMMENT_PERMISSION, READ_PERMISSION} = require('./model')
{ModelType, ModelField, ParamsField} = require('../editor/model')
{Editor} = require('../editor/editor_v2')
getGadgetLinkEditor = require('../editor/gadget/gadget_link_editor').get
{ROLE_OWNER, ROLE_EDITOR, ROLE_COMMENTATOR} = require('../wave/participants/constants')
{Contributors} = require('./contributors')
{Author} = require('./contributors/author')
{TaskRecipient} = require('./task_recipient')
{TaskRecipientInput} = require('./task_recipient/input')
{Recipient, RecipientInput} = require('./recipient')
{renderBlip} = require('./template')
RangeMenu = require('./menu/range_menu')
{BlipThread} = require('./blip_thread')
DOM = require('../utils/dom')
MicroEvent = require('../utils/microevent')
{escapeHTML} = require('../utils/string')
{formatDate} = require('../../share/utils/datetime')
BrowserEvents = require('../utils/browser_events')
{LocalStorage} = require('../utils/localStorage')
BrowserSupport = require('../utils/browser_support')
async = require('async')
{trackParticipantAddition} = require('../wave/participants/utils')
{BlipEventInteractor} = require('./interactor')

# TODO: remove it
READ_TOPIC_MODE = 'read_topic_mode'
EDIT_TOPIC_MODE = 'edit_topic_mode'

class BlipView extends BlipViewBase
    ###
    Класс для отображения одного сообщения в документе
    ###

    constructor: (@_waveViewModel, @_blipProcessor, @_blipViewModel, @_model, @_ts, @_blipContainer, @_parent, isRead) ->
        ###
        Создает объект для отображения блипа
        @param _waveViewModel: WaveViewModel
        @param _blipProcessor: BlipProcessor
        @param _model: BlipModel
        @param snapshot: текущий снимок блипа
        @param ts: время последнего редактирования
        @param _blipContainer: HTMLNode, нода, в которой отображаться блипу
        @param _parent: BlipView, родитель, нужен для кнопки "удалить"
        @param isRead: boolean
        ###
        super()
        # TODO: save it in base class when base init method will be ready
        @__blipContainer = @_blipContainer
        # TODO: save it in base class when base init method will be ready
        @__model = @_model
        @_blipContainer['__rizzoma_id'] = @_model.id #идентификатор блипа, который привязан к ноде. Возможно не самое лучшее место для установки ид
        @_requestedBlips = {}
        @_childBlips = @_model._childBlips # TODO: hack. childBlips should be stored in model
        @_init(isRead)
        @_messagesProcessor = require('../search_panel/mention/processor').instance
        @_tasksProcessor = require('../search_panel/task/processor').instance
        if @isRoot()
            DOM.addClass(@_blipContainer, 'root-blip')
        @_canEdit = BrowserSupport.isSupported() and not @_isAnonymous

    _init: (isRead) ->
        ###
        Инициализирует объект
        ###
        @_rendered = false
        @__isNotInRootThread = @_parent?.getParent()?
        if not @_parent
            @_render()
        else
            @__unreadIndicatorHidden = true
            blipThread = BlipThread.getBlipThread(@_blipContainer)
            if blipThread
                blipThread.setAsRoot() if @isRoot()
                @__initFold()
            else
                @_blipContainer.addEventListener(BrowserEvents.C_BLIP_INSERT_EVENT, @__initFold, false)
            $(@_blipContainer).on('focusin', @_processFocusInEvent).on('focusout', @_processFocusOutEvent)
            if isRead?
                @_focused = no
                if isRead
                    @_markAsRead()
                else
                    @_markAsUnread()
            else
                @_focused = yes
            @_initChildBlips(@_model.getSnapshotContent())
        @_waveViewModel.on('usersInfoUpdate', @_usersInfoUpdateHandler)

    _render: ->
        # TODO: make base method
        return if @_rendered
        @_rendered = true
        @_createDOM(@_ts)
        if @_parent
            @_initBlipInfo(@_model.getContributors())
            @__initUnreadIndicator()
        @_blipContainer.addEventListener(BrowserEvents.DRAG_OVER_EVENT, @_preventDragDropEvent, no)
        $(@_blipContainer).find('.js-finish-edit').click => # TODO: move it to right place
            @_setEditable(no, yes)
        @_initEditor(@_model.getSnapshotContent())
        @_initBlipEventsInteractor()
        @_setPermission()
        @_setEditable(@_waveViewModel.getView().isEditMode(), no)
        @updateReadState()

    _initBlipEventsInteractor: () ->
        @_interactor = new BlipEventInteractor(@_blipViewModel, @)

    renderRecursively: ->
        @_render()
        for blipId, blip of @_childBlips
            blip.getView().renderRecursively()

    renderRecursivelyToRoot: ->
        return if @_rendered
        @_parent.renderRecursivelyToRoot()
        @_render()

    _initChildBlips: (content) ->
        for block in content
            continue if block[ModelField.PARAMS][ParamsField.TYPE] isnt ModelType.BLIP
            @_addInlineBlip(block[ModelField.PARAMS][ParamsField.ID])

    _initBlipInfo: (contributors) ->
        ###
        Инициализирует элемент, отвечающий за информацию о блипе
        ###
        c = $(@_blipContainer)
        $shownContributorContainer = c.find('.js-shown-contributor')
        authors = [contributors[0].id]
        authors.push(contributors[1].id) if contributors.length > 1
        author = new Author(@_waveViewModel, authors)
        @_contributors = new Contributors(@_waveViewModel, contributors, author)
        $shownContributorContainer.append(author.getContainer())
        c.find('.js-blip-info-container').append(@_contributors.getContainer())

    _attachMenu: ->
        [lastSent, lastSender] = @_getLastSentParams()
        params =
            canEdit: @_hasEditPermission()
            foldable: @_hasChildBlips()
            foldedByDefault: @_model.isFoldedByDefault()
            sendable: @_hasRecipients()
            lastSent: lastSent
            lastSender: lastSender
            isRoot: @isRoot()
            handlers:
                hasServerId: @_model.serverId?
        @_interactor.attachMenu(@_waveViewModel.getBlipMenu(), @_menuContainer, params)
        @_onServerId =>
            @_interactor?.enableIdDependantButtons()

    _detachMenu: ->
        @_interactor.detachMenu()

    _getLastSentParams: ->
        lastSent = 0
        message = @_blipViewModel.getModel().getMessageInfo()
        if message
            lastSent = message.lastSent
            lastSenderId = message.lastSenderId
        return [null, null] unless @_editor
        for recipient in @_editor.getTaskRecipients()
            data = recipient.getData()
            curLastSent = data.lastSent
            continue if not curLastSent
            continue if curLastSent < lastSent
            lastSent = curLastSent
            lastSenderId = data.lastSenderId
        lastSender = null
        if lastSent and lastSenderId
            lastSender = @_blipViewModel.getWaveViewModel().getUser(lastSenderId).getName()
        return [lastSent, lastSender]

    _setReplyButtonHandler: ->
        @_replyButton = $(@_blipContainer).find('.js-blip-reply-button')[0]
        $(@_replyButton).on 'click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Re in bottom blip menu'])
            @insertReplyBlip()

    insertReplyBlip: ->
        blipViewModel = @_parent.initInsertInlineBlip(yes, {}, BlipThread.getBlipThread(@_blipContainer))

    _onServerId: (callback) ->
        ###
        Вызывает callback, когда у текущего блипа появится serverId. Вызывает сразу, если serverId уже есть.
        ###
        return callback() if @_model.serverId
        @_blipViewModel.on('set-server-id', callback)

    _insertRecipientByEmail: (position, email, callback) =>
        @_onServerId =>
            @_messagesProcessor.addRecipientByEmail @_model.serverId, @_model.getVersion(), position, email, (err, user) =>
                callback()
                if err
                    message = "Could not add recipient #{email}"
                    message += ": #{err.logId}" if err.logId
                    @_waveViewModel.showWarning(message)
                    return console.error(err)
                trackParticipantAddition('By mention', user)
                @_waveViewModel.updateUserInfo(user)

    _addTaskRecipient: (params, callback) =>
        @_onServerId =>
            params.blipId = @_model.serverId
            params.version = @_model.getVersion()
            @_tasksProcessor.assign params, (err, user) =>
                callback()
                if err
                    message = "Could not add task recipient #{params.recipientEmail}"
                    message += ": #{err.logId}" if err.logId
                    @_waveViewModel.showWarning(message)
                    return console.error(err)
                trackParticipantAddition('By task', user)
                @_waveViewModel.updateUserInfo(user)

    _initEditor: (content) ->
        ###
        Инициализирует редактор содержимого блипа
        ###
        c = $(@_blipContainer)
        @_editorNode = c.find('.js-editor-container')[0]
        lightBoxId = escapeHTML(@_model.id)
        functions =
            getChildBlip: (id) =>
                @_childBlips[id]
            getSnapshot: @_getContent
            addInlineBlip: @_addInlineBlip
            removeInlineBlip: @_removeInlineBlip
            getRecipientInput: @_getRecipientInput
            getRecipient: @_getRecipient
            addRecipientByEmail: @_insertRecipientByEmail
            getTaskRecipientInput: @_getTaskRecipientInput
            getTaskRecipient: @_getTaskRecipient
            addTaskRecipient: @_addTaskRecipient
            getNewChildBlip: (insertInBlip, params, thread) =>
                @initInsertInlineBlip(insertInBlip, params, thread)
            getScrollableElement: =>
                @_waveViewModel?.getView()?.getScrollableElement()
        @_editor = new Editor(lightBoxId, {}, functions, no)
        @_editor.on 'ops', @_processEditorChanges
        @_editor.on 'error', (e) =>
            @_editor.setEditable(no)
            @_editor.removeListener('ops', @_processEditorChanges)
            @_blipProcessor.showPageError(e)
        @_editor.on 'copy', =>
            @renderRecursively()
        @_editor.initContent()
        editorContainer = @_editor.getContainer()
        @_editorNode.appendChild(editorContainer)
        DOM.addClass(editorContainer, 'container-blip-editor') unless @_parent

    updateLastSent: ->
        [lastSent, lastSender] = @_getLastSentParams()
        @_interactor?.setLastSent(lastSent, lastSender)

    FROM_BOTTOM_BLIP_BORDER = 65
    MENU_TOP_OFFSET = 19

    _resetMenuPosition: ->
        DOM.removeClass(@_menuContainer, 'fixed')
        @_menuContainer?.removeAttribute('style', 0)

    updateMenuLeftPosition: ->
        return if @isRoot()
        $menuContainer = $(@_menuContainer)
        return unless $menuContainer.hasClass('fixed')
        $menuContainer.css('left', "#{@getContainer().getBoundingClientRect().left}px")

    updateMenuPosition: ->
        # TODO: fails with window scrolls
        return if @isRoot()
        containerRect = @getContainer().getBoundingClientRect()
        scrollable = @_waveViewModel?.getView()?.getScrollableElement()
        return unless scrollable
        scrollableOffsetTop = scrollable.offsetTop
        blipOffsetTop = containerRect.top - scrollableOffsetTop

        scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop

        $menuContainer = $(@_menuContainer)
        if blipOffsetTop > MENU_TOP_OFFSET # reset by top
            return @_resetMenuPosition()

        cancelMenuScrollChanges = containerRect.bottom - scrollableOffsetTop < 0 or containerRect.bottom - scrollableOffsetTop < FROM_BOTTOM_BLIP_BORDER
        if cancelMenuScrollChanges # reset by bottom
            return @_resetMenuPosition()

        css = {}
        $menuContainer.addClass('fixed')
        if !@__isNotInRootThread then leftOffsetCorrection = 32 else leftOffsetCorrection = 0
        css.left = containerRect.left + leftOffsetCorrection
        css.top = if scrollTop then Math.max(scrollableOffsetTop - scrollTop, 0) else ''
        $menuContainer.css(css)

    _handleSend: (callback) ->
        return callback() unless @_model.serverId
        async.parallel [@_sendMessages, @_sendTasks], (err) ->
            callback(err)

    _sendMessages: (callback) =>
        return callback(null) if not @_editor.getRecipients().length
        isFirstSend = not @_model.getMessageInfo()?.lastSent?
        @_messagesProcessor.send @_model.serverId, (error, message) =>
            return callback(error) if error
            recipients = @_editor.getRecipients()
            for recipient in recipients
                id = recipient.getId()
                if message?.hasOwnProperty(id)
                    # process errors
                    recipient.markAsInvalid(message[id].message)
                    sendError = true
                else
                    # ok
                    continue unless id
                    recipient.render()
            if sendError
                error = new Error('Not all recipients were sent')
                error.explanation = "Error while sending #{formatDate(Date.now()/1000)}"
                return callback(error)
            eventLabel = if isFirstSend then 'First time' else 'Again'
            _gaq.push(['_trackEvent', 'Mention', 'Mention sending', eventLabel, recipients.length])
            callback(null)

    _sendTasks: (callback) =>
        return callback(null) if not @_editor.getTaskRecipients().length
        isFirstSend = not @_model.getMessageInfo()?.lastSent?
        @_tasksProcessor.send @_model.serverId, (error, message) =>
            return callback(error) if error
            recipients = @_editor.getTaskRecipients()
            for recipient in recipients
                id = recipient.getRecipientId()
                if message?.hasOwnProperty(id)
                    # process errors
                    recipient.markAsInvalid(message[id].message)
                    sendError = true
                else
                    # ok
                    continue unless id
                    recipient.markAsValid()
            if sendError
                error = new Error('Not all tasks were sent')
                error.explanation = "Error while sending #{formatDate(Date.now()/1000)}"
                return callback(error)
            eventLabel = if isFirstSend then 'First time' else 'Again'
            _gaq.push(['_trackEvent', 'Task', 'Task sending', eventLabel, recipients.length])
            callback(null)

    _getContent: =>
        @_model.getSnapshotContent()

    _createDOM: (ts) ->
        ###
        Создает все необходимые для отображения сообщения DOM-ноды
        ###
        c = $(@_blipContainer)
        params =
            isNotInRootThread: @__isNotInRootThread
            isRoot: not @_parent # проверка на обертку над рутовым блипом
            datetime: formatDate ts
            fullDatetime: formatDate(ts, true)
            isAnonymous: !window.loggedIn
        c.addClass('blip-container')
        if not @_parent
            c.prepend(renderBlip(params))
        else
            c.append(renderBlip(params))
        @_editorNode = c.find('.js-editor-container')[0]
        if @isRoot()
            @_menuContainer = $(@_waveViewModel.getView().container).find('.js-wave-panel')[0]
        else
            @_menuContainer = c.find('.js-blip-menu-container')[0] or null
        @_setReplyButtonHandler()

    recursivelyUpdatePermission: ->
        @_updatePermission()
        for _, blip of @_childBlips
            blip.getView().recursivelyUpdatePermission()

    _getPermission: =>
        role = @_waveViewModel?.getRole()
        switch role
            when ROLE_OWNER then permission = EDIT_PERMISSION
            when ROLE_EDITOR then permission = EDIT_PERMISSION
            when ROLE_COMMENTATOR
                if @_model.getAuthorId() in window.userInfo.mergedIds
                    permission = EDIT_PERMISSION
                else
                    permission = COMMENT_PERMISSION
            else permission = READ_PERMISSION
        permission

    _hasEditPermission: -> @_getPermission() is EDIT_PERMISSION

    _setPermission: -> # TODO: bad function name
        @_permission = @_getPermission()
        return if not @_rendered
        @_editor.setPermission(@_permission)
        if hasEditPermission = @_hasEditPermission()
            $(@_blipContainer).removeClass('non-editable')
        else
            $(@_blipContainer).addClass('non-editable')
        @_interactor?.setCanEdit(hasEditPermission)

    _updatePermission: ->
        @_setPermission()
        @_setEditable(@_editable, no)

    _setModeStyle: (editable) ->
        funcName = if editable then 'addClass' else 'removeClass'
        if @isRoot()
            $(@_waveViewModel.getView().getContainer()).find('.js-wave-panel')[funcName]('edit-mode')
        else
            $(@_blipContainer)[funcName]('edit-mode')

    _setEditable: (editable, updateGlobally) ->
        return @_editable = no if not @_parent or not @_editor
        if editable and @_hasEditPermission() and @_canEdit
            @_interactor.setEditableMode(yes)
            @_updateUndoRedoState()
            RangeMenu.get().hide()
            @_setModeStyle(yes)
            @_editable = yes
        else
            @_interactor.setEditableMode(no)
            @_setModeStyle(no)
            @_editable = no
        @_editor.setEditable(@_editable)
        return unless updateGlobally
        if @_editable
            @_waveViewModel.getView().setEditModeEnabled(yes)
        else
            @_waveViewModel.getView().setEditModeEnabled(no)

    getPermission: -> @_permission

    _processFocusInEvent: (event) =>
        @_focused = yes
        @setReadState(true)
        event.stopPropagation()

    _processFocusOutEvent: (event) =>
        @_focused = no
        @setReadState(true)
        event.stopPropagation()

    addChildToUnreads: (id) ->
        blipThread = BlipThread.getBlipThread(@_blipContainer)
        if blipThread?.blipIsUnread(id)
            return
        blipThread?.setUnreadBlip(id)
        @_parent?.addChildToUnreads(id)

    removeChildFromUnreads: (id) ->
        blipThread = BlipThread.getBlipThread(@_blipContainer)
        if blipThread and (not blipThread.blipIsUnread(id))
            return
        blipThread?.removeUnreadBlip(id)
        @_parent?.removeChildFromUnreads(id)

    _markAsRead: ->
        @__hideUnreadIndicator()
        @_model.isRead = true
        @_waveViewModel.setBlipAsRead(@_model.serverId) if @_model.serverId

    markAsRead: -> @_markAsRead()

    _markAsUnread: ->
        @__showUnreadIndicator()
        @_model.isRead = false
        @_waveViewModel.setBlipAsUnread(@_model.serverId) if @_model.serverId

    markAsUnread: -> @_markAsUnread()

    setReadState: (isRead, sendToServer=true) ->
        return if isRead is @_model.isRead
        if not @_model.serverId
            if isRead
                @_markAsRead()
            else
                @_markAsUnread()
            return
        if isRead
            @_waveViewModel.setBlipAsRead(@_model.serverId)
        else
            @_waveViewModel.setBlipAsUnread(@_model.serverId)
        params =
            waveId: @_waveViewModel.getServerId()
            blipId: @_model.serverId
            unreadBlipsCount: @_waveViewModel.getUnreadBlipsCount()
            totalBlipsCount: @_waveViewModel.getTotalUsableBlipsCount()
            isRead: isRead
        LocalStorage.updateBlipReadState(params)
        if isRead and sendToServer
            @_blipProcessor.updateBlipReader(@_blipViewModel)
            @_waveViewModel.checkBlipSetAsRead(@_model.serverId)

    _usersInfoUpdateHandler: (userIds) =>
        ###
        Обработчик события обновления информации о пользователях
        ###
        lastSenderId = @_model.getMessageInfo()?.lastSenderId
        if lastSenderId and $.inArray(lastSenderId, userIds)
                @updateLastSent()

    initInsertInlineBlip: (insertIntoEditor = yes, params = {}, thread = null) ->
        ###
        Начинает вставку вложенного сообщения
        @param insertToEnd: boolean, нужно ли вставить дочерний блип в конец
        @return: blipViewModel
        ###
        #@_detachMenu() # TODO: remove it (run it synchronously) : убираем обработчики шорткатов и курсора с текущего блипа, заметно при зажатии Ctrl+Enter
        container = @_getChildBlipContainer()
        @_waveViewModel.getView().setEditModeEnabled(yes) if !@_waveViewModel.getView().isEditMode()
        blipViewModel = require('./processor').instance.createBlip(@_waveViewModel, container, params, @_blipViewModel)
        if insertIntoEditor
            if thread
                thread.appendBlipElement(container)
            else
                blipThread = new BlipThread("#{Math.random()}", container)
                blipThread.unfold()
                @_editor.insertNodeAtCurrentPosition(blipThread.getContainer())
        @_childBlips[blipViewModel.getModel().id] = blipViewModel
        blipViewModel.on 'set-server-id', (serverId) =>
            if not @_editor.insertBlip(serverId, container, (thread || blipThread).getId(), !!thread)
                blipViewModel.destroy()
        blipViewModel.getView().renderRecursively()
        blipViewModel.getView().focus()
        # Оповестим waveView об изменении положения курсора
        window.setTimeout =>
            @_waveViewModel.getView().runCheckRange()
        , 0
        # эмитим событие у родителя вставляемого блипа, чтоб скинуть
        # режим редактирования у последнего редактируемого
        # блипа если вставляем в нередактируемого родителя
        # по идее срабатывает только на вставку инлайна
        @_updateChildBlipsCounter()
        return blipViewModel

    initInsertImage: ->
        getUploadForm().open(@_editor, yes)

    initInsertFile: ->
        getUploadForm().open(@_editor, no)

    initLinkManagement: ->
        ###
        Вызывает редактор ссылок для указанного диапазона
        ###
        @_editor?.openLinkEditor()

    initInsertGadget: ->
        ###
        Вызывает редактор ссылки для гаджета
        ###
        getGadgetLinkEditor().open(@_editor)

    _processEditorChanges: (ops) =>
        @submitOps(ops)
        @_updateUndoRedoState()
        try
            @_onEditorUpdate()
        catch err
            console.warn(err)

    _getChildBlipContainer: ->
        res = document.createElement 'span'
        res.contentEditable = 'false'
        return res

    _addInlineBlip: (serverBlipId) =>
        ###
        Добавляет вложенный в текущий блип
        @param serverBlipId: string
        @return: HTMLElement, контейнер вставки
        ###
        container = @_getChildBlipContainer()
        childBlipId = @_getChildBlipId(serverBlipId)
        if childBlipId
            # Дочерний блип уже был создан ранее, используем его
            childBlip = @_childBlips[childBlipId]
            return childBlip.getView().getContainer()
        if @_requestedBlips[serverBlipId]
            return @_requestedBlips[serverBlipId]
        # Дочерний блип нужно запрашивать с сервера
        @_requestedBlips[serverBlipId] = container
        @_newChildBlip serverBlipId, container, (err, blipViewModel) =>
            # блип уже был удален либо загружен, если его нет в запрошенных
            return if not @_requestedBlips[serverBlipId]?
            return @_blipProcessor.showPageError(err) if err
            delete @_requestedBlips[serverBlipId]
            if @_childBlips?
                @_childBlips[blipViewModel.getModel().id] = blipViewModel
                @_updateChildBlipsCounter()
            else
                # there is no childBlips because current blip was closed
                blipViewModel.close()
        return container

    _getChildBlipId: (serverBlipId) ->
        ###
        Возвращает идентификатор вложенного блипа по серверному id
        @param serverBlipId: string
        @return: string|null
        ###
        for blipId, blip of @_childBlips
            return blipId if blip.getModel().serverId is serverBlipId
        return null

    _removeInlineBlip: (serverBlipId) =>
        ###
        Удаляет вложенный в текущий блип
        @param blipId: string
        ###
        delete @_requestedBlips[serverBlipId] if @_requestedBlips[serverBlipId]?
        blipId = @_getChildBlipId(serverBlipId)
        return if blipId is null
        childBlip = @_childBlips[blipId]
        childContainer = childBlip.getView().getContainer()
        childThread = BlipThread.getBlipThread(childContainer)
        if childThread?.isFirstInThread(childContainer)
            secondBlipId = childThread.getSecondBlipElement()?['__rizzoma_id']
            @_childBlips[secondBlipId].getView().setFoldedByDefault(childBlip.getModel().isFoldedByDefault()) if secondBlipId
        childBlip.destroy()
        delete @_childBlips[blipId]
        @_updateChildBlipsCounter()

    _getRecipient: (args...) =>
        canDelete = (id) =>
            @_hasEditPermission() or id is window.userInfo?.id
        canConvert = (id) =>
            @_hasEditPermission()
        new Recipient(@_waveViewModel, canDelete, canConvert, args...)

    _getRecipientInput: =>
        new RecipientInput(@_waveViewModel)

    _getTaskRecipientInput: =>
        new TaskRecipientInput(@_waveViewModel, @_updateTaskSearchInfo)

    _updateTaskSearchInfo: (data) =>
        info =
            waveId: @_waveViewModel.getServerId()
            blipId: @_model.serverId
            changed: true
            title: @_model.getTitle()
            snippet: @_model.getSnippet()
            isRead: true
            status: data.status
        if data.deadlineDate? or data.deadlineDatetime
            info.deadline =
                date: data.deadlineDate
                datetime: data.deadlineDatetime
        if data.recipientId?
            recipient = @_waveViewModel.getUser(data.recipientId)
            info.recipientName = recipient.getName()
            info.recipientEmail = recipient.getEmail()
            info.recipientAvatar = recipient.getAvatar()
        else
            info.recipientEmail = data.recipientEmail
        sender = @_waveViewModel.getUser(data.senderId)
        info.senderName = sender.getName()
        info.senderEmail = sender.getEmail()
        info.senderAvatar = sender.getAvatar()
        @_tasksProcessor.updateTaskSearchInfo(info)

    _getTaskRecipient: (args...) =>
        canEditBlip = =>
            @_permission is EDIT_PERMISSION
        new TaskRecipient(@_waveViewModel, args..., @_updateTaskSearchInfo, canEditBlip)

    _hasChildBlips: ->
        for _ of @_childBlips
            return yes
        no

    _hasRecipients: -> @_editor.hasRecipientsOrTasks()

    _updateChildBlipsCounter: ->
        @_interactor?.setFoldable(@_hasChildBlips())

    _updateRecipientsCounter: ->
        @_interactor?.setSendable(@_hasRecipients())

    _onEditorUpdate: ->
        # Called when editor is updated by user or others
        @_updateRecipientsCounter()

    setEditable: (editable) ->
        if not @_canEdit
            return alert("You need to use the lastest version of Chrome, Firefox, Safari or Internet Explorer in order to edit")
        @_setEditable(editable, yes)

    focus: ->
        ###
        Устанавливает курсор в текущий редактор
        ###
        @setReadState(true)
        @_editor?.focus()

    markActive: =>
        return unless @_parent
        @_isActive = yes
        @_attachMenu()
        editMode = @_waveViewModel.getView().isEditMode()
        DOM.addClass(@_menuContainer, 'active') if @isRoot()
        DOM.addClass(@_blipContainer, 'active')
        @_setEditable(editMode, no)

    unmarkActive: =>
        # TODO: menuContainer?
        $(@_menuContainer).removeClass('fixed')
        if @_waveViewModel
            # такая проверка на то что блип не удален
            # TODO: ---Семенов--- попробовать придумать как по-другому проверить | ошибка "Cannot call method 'getRole' of undefined"
            @_isActive = no
            DOM.removeClass(@_menuContainer, 'active') if @isRoot()
            DOM.removeClass(@_blipContainer, 'active')
            @_detachMenu()
            @_setEditable(no, no)

    isActive: -> @_isActive

    removeChild: (id) ->
        ###
        Удаляет дочерний блип
        @param id: string
        ###
        blip = @_childBlips[id]
        return if not blip
        if blip.getModel().serverId?
            return @_editor.removeBlip(blip.getModel().serverId)
        blip.destroy()
        window.getSelection()?.removeAllRanges()
        delete @_childBlips[id]
        @_updateChildBlipsCounter()

    remove: -> @_parent.removeChild(@_model.id)

    getContainer: -> @_blipContainer

    _newChildBlip: (serverBlipId, container, callback) ->
        ###
        Создает объект вложенного блипа
        @param serverBlipId: string, идентификатор блипа
        @param container: HTMLNode, нода, в которой будет сообщение
        @param callback: function
            callback(BlipViewModel)
        ###
        require('./processor').instance.openBlip(@_waveViewModel, serverBlipId, container, @_blipViewModel, callback)

    applyisFoldedByDefaultOp: (op) ->
        @_interactor?.updateFoldedByDefault(op.oi)

    applyParticipantOp: (op) ->
        return unless @_parent
        @_contributors?.applyOp op

    _opSetsUnreadIndicator: (op) ->
        if op.paramsi or op.paramsd
            param = op.paramsi || op.paramsd
            for paramName of param
                return false if paramName is 'lastSent' or paramName is 'lastSenderId'
        return true if not (op.ti? or op.td?)
        blockType = op[ModelField.PARAMS][ParamsField.TYPE]
        return false if blockType is ModelType.BLIP
        return false if op.td? and blockType in [ModelType.RECIPIENT, ModelType.TASK_RECIPIENT]
        return true

    _opsSetUnreadIndicator: (ops) ->
        for op in ops
            return true if @_opSetsUnreadIndicator(op)

    _isMyMeta: (meta) ->
        if meta?.user?
            return true if meta.user is window.userInfo?.id

    applyOps: (ops, shiftCursor, meta) ->
        ###
        Применяет операции, сделанные другими пользователями
        @param ops: [ShareJS operation]
        @param shiftCursor: boolean, смещать ли курсор к выполненной операции
        @param meta: object, метаинформация к операциям, если они пришли с сервера
        ###
        if @_editor
            user = null
            if meta? and meta.user? and not @_isMyMeta(meta)
                u = @_waveViewModel.getUser(meta.user)
                if u.isLoaded() and (name = u.getRealName() or u.getEmail())
                    user = {name: name, id: u.getId()}
            @_editor.applyOps(ops, shiftCursor, user)
            try
                @_onEditorUpdate()
            catch err
                console.warn(err)
        else
            @_processBlipOps(ops)
        return if @_focused
        if meta? and @_isMyMeta(meta)
            @setReadState(true)
        else if @_opsSetUnreadIndicator(ops)
            @setReadState(false)

    _processBlipOps: (ops) ->
        changedBlipIds = {}
        for op in ops
            continue if (not op.ti?) and (not op.td?)
            opType = op[ModelField.PARAMS][ParamsField.TYPE]
            continue if opType isnt ModelType.BLIP
            blipId = op[ModelField.PARAMS][ParamsField.ID]
            changedBlipIds[blipId] = true
            haveChanges = true
        return if not haveChanges
        for block in @_model.getSnapshotContent()
            id = block[ModelField.PARAMS][ParamsField.ID]
            continue if id not of changedBlipIds
            delete changedBlipIds[id]
            @_addInlineBlip(id)
        for id of changedBlipIds
            @_removeInlineBlip(id)

    submitOps: (ops) ->
        ###
        Отправляет операции пользователя на сервер
        @param ops: [ShareJS operation]
        ###
        return if not ops.length
        try
            @_model.submitOps(ops)
            @emit('ops', ops)
        catch e
            @_editor.removeListener('ops', @_processEditorChanges)
            @_editor.setEditable(no)
            @_blipProcessor.showPageError(e)

    isRead: ->
        return @_model.isRead

    getParent: ->
        return @_parent

    setFoldedByDefault: (folded) ->
        @_model.setIsFoldedByDefault(folded)
        @_interactor?.updateFoldedByDefault(folded)

    getChildBlipByServerId: (serverBlipId) ->
        ###
        Возвращает объект со вложенными блипами
        @return: BlipViewModel|null
        ###
        childBlipId = @_getChildBlipId(serverBlipId)
        return null if not childBlipId?
        @_childBlips[childBlipId]

    getBlipCopyOpByServerId: (serverBlipId) ->
        @renderRecursively()
        childBlipContainer = @getChildBlipByServerId(serverBlipId)?.getView().getContainer()
        return null if not childBlipContainer
        return @_editor.getCopyElementOp(childBlipContainer)

    _preventDragDropEvent: (e) ->
        e.stopPropagation()
        e.preventDefault()
        e.dataTransfer?.dropEffect = 'none'

    removeWithConfirm: ->
        ###
        Удаляет это сообщение
        ###
        if window.confirm("Delete reply?")
            _gaq.push(['_trackEvent', 'Blip usage', 'Delete blip'])
            @remove()

    sendMessages: (callback) -> @_handleSend(callback)

    destroy: ->
        super()
        @_blipContainer.removeEventListener(BrowserEvents.DRAG_OVER_EVENT, @_preventDragDropEvent, no)
        @removeAllListeners()
        @_interactor?.destroy()
        delete @_interactor
        delete @_blipViewModel
        @_waveViewModel.setBlipAsRemoved(@_model.serverId) if @_model.serverId
        @_waveViewModel.removeListener('usersInfoUpdate', @_usersInfoUpdateHandler)
        delete @_waveViewModel
        if @_parent
            @_contributors?.destroy()
            delete @_contributors
            delete @_parent
        @_editor?.destroy()
        # Редактор нужен даже после закрытия, надо исправлять
        #delete @_editor
        delete @_model
        $(@_blipContainer).remove()

    getBlipContainingCursor: (cursor) ->
        ###
        Возвращает самый вложенный блип, который содержит в себе указанный курсор
        @param cursor: [HTMLElement, int]
        @return: BlipView|null
        ###
        return null if not @_editor
        return @ if @_editor.getContainer() is cursor[0]
        return null if not @_editor.containsNode(cursor[0])
        for _, blip of @_childBlips
            res = blip.getView().getBlipContainingCursor(cursor)
            return res if res
            return null if blip.getView().getBlipContainingElement(cursor[0])
        return @

    getBlipContainingElement: (e) ->
        ###
        Возвращает самый вложенный блип, который содержит в себе указанный элемент
        @param e: HTMLElement
        @return: BlipView|null
        ###
        return null if not DOM.contains(@_blipContainer, e)
        for _, blip of @_childBlips
            res = blip.getView().getBlipContainingElement(e)
            return res if res
        return @

    getEditor: ->
        ###
        Возвращает редактор внутри этого блипа
        @return: Editor
        ###
        return @_editor

    getUrl: ->
        ###
        Возвращает ссылку на блип
        @return: string
        ###
        "#{@_waveViewModel.getView().getUrl()}#{@_model.serverId}/"

    isRoot: -> @_model?.getServerId() is @_waveViewModel?.getRootBlipId()

    setCursor: ->
        @_interactor.updateEditingModifiers()
        @_editor.setCursor()

    updateCursor: ->
        @_interactor.updateEditingModifiers()
        @_editor.updateCursor()

    clearCursor: ->
        @_editor.clearCursor()

    getViewModel: ->
        #TODO: hack
        @_blipViewModel

    markLastEdit: ->
        ###
        Ставится класс для пометки последного редактируемого блипа синей рамкой
        ###
        $(@_blipContainer).addClass('last-active')

    unmarkLastEdit: ->
        ###
        Снимается класс для пометки последного редактируемого блипа синей рамкой
        ###
        $(@_blipContainer).removeClass('last-active')

    setRangeMenuPosByRange: (r, parent) ->
        rangeMenu = RangeMenu.get()
        return rangeMenu.hide() unless rect = @_getRectFromRange(r, parent)
        editCallback = null
        if @_hasEditPermission
            editCallback = =>
                @_setEditable(yes, yes)
        rangeMenu.show @_model.getId(), rect, parent, =>
            @initInsertInlineBlip()
        , editCallback

    updateRangeMenuPosByRange: (r, parent) ->
        rangeMenu = RangeMenu.get()
        return rangeMenu.hide() unless rect = @_getRectFromRange(r, parent)
        rangeMenu.update(rect)

    _getRectFromRange: (r, parent) ->
        return unless @_isActive
        return if @_editable
        return unless r
        try
            return if @_getPermission() is READ_PERMISSION
            rect = @_editor.getCursorRectFromRange(r, parent)
        catch e
            return console.warn('Failed to get permissions for RangeMenu')
        return unless rect
        return if not rect.top and not rect.bottom and not rect.left and not rect.right
        DOM.convertWindowCoordsToRelative(rect, parent)
        return if rect.bottom > parent.clientHeight
        rect

    _updateUndoRedoState: -> @_interactor.updateUndoRedoState()

    showPlaybackView: () ->
        @_blipProcessor.showPlaybackView(@_waveViewModel.getServerId(), @_model.serverId)

MicroEvent.mixin(BlipView)
module.exports = {BlipView}
