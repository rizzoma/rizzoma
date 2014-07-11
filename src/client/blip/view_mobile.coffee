DOM = require('../utils/dom')
BlipViewBase = require('./view_base')
BrowserSupport = require('../utils/browser_support_mobile')
ModelType = require('../editor/model').ModelType
ModelField = require('../editor/model').ModelField
ParamsField = require('../editor/model').ParamsField

if BrowserSupport.isContentEditableSupported()
    if BrowserSupport.isWebKit() or BrowserSupport.isMozilla()
        Editor = require('../editor/editor_mobile_v2').Editor
    else
        Editor = require('../editor/editor_mobile').Editor
else
    Editor = require('../editor/editor_mobile_polyfill').Editor

Contributors = require('./contributors').Contributors
Author = require('./contributors/author').Author
{Recipient, RecipientInput} = require('./recipient')
{TaskRecipient} = require('./task_recipient')
{TaskRecipientInput} = require('./task_recipient/input')
{formatDate} = require('../../share/utils/datetime')
popup = require('../popup').popup
BlipMenu = require('./menu/mobile').BlipMenu
MicroEvent = require('../utils/microevent')
escapeHTML = require('../utils/string').escapeHTML
BrowserEvents = require('../utils/browser_events')
BlipThread = require('./blip_thread').BlipThread
{EDIT_PERMISSION, COMMENT_PERMISSION, READ_PERMISSION} = require('./model')
{ROLE_OWNER, ROLE_EDITOR, ROLE_COMMENTATOR} = require('../wave/participants/constants')

blipTmpl = ->
    if not @isRoot
        div '.js-blip-menu-container.blip-menu-container', ''
        div '.js-blip-info-container.blip-info', ->
            span '.js-shown-contributor', ->
            div ->
                div '.edit-date', {title: h(@fullDatetime)}, h(@datetime)
    div '.js-editor-container.editor-container', ->
        if not @isRoot
            div '.js-blip-unread-indicator.unread-indicator', style: 'display: none;', ->
    if not @isRoot and @isNotInRootThread and not @isAnonymous
        button '.js-blip-reply-button.blip-reply-button', {title: 'Add reply'}, ->
            img '', {src: "/s/img/reply_icon.png"}
            text 'Reply'

renderBlip = window.CoffeeKup.compile(blipTmpl)

EditorConfig =
    lightbox: {
        containerMarginLeftRightSize: 0
        containerBorderSize: 0
        topOffset: 0
        fixedNavigation: yes
        hideImageDataBox: yes
    }

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
        if @_model.getServerId() is @_waveViewModel.getModel().getRootBlipId()
            DOM.addClass(@_blipContainer, 'root-blip')

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
            if BlipThread.getBlipThread(@_blipContainer)
                @__initFold()
            else
                @_blipContainer.addEventListener(BrowserEvents.C_BLIP_INSERT_EVENT, @__initFold, false)
            $(@_blipContainer).on('focusin', @_processFocusInEvent).on('focusout', @_processFocusOutEvent)
            if isRead?
                @_focused = no
                if isRead
                    @_markAsRead(false)
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
        @_initEditor(@_model.getSnapshotContent())
        @updateReadState()

    renderRecursively: ->
        @_render()
        for blipId, blip of @_childBlips
            blip.getView().renderRecursively()

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

    _initMenu: ->
        ###
        Инициализирует меню блипа
        ###
        c = $(@_menuContainer)
        params =
            isFoldedByDefault: @_model.isFoldedByDefault()
            hasServerId: @_model.serverId?
        @_blipMenu = new BlipMenu(params)
        $(@_menuContainer).append(@_blipMenu.getContainer())
        @_menu = c.find('.js-blip-menu')[0]
        @_deleteButton = c.find('.js-delete-blip')[0]
        $(@_deleteButton).bind 'mousedown', @_remove
        @_isFoldedByDefaultBox = c.find('.js-is-folded-by-default')[0]
        $(@_isFoldedByDefaultBox).bind 'mousedown', @_setIsFoldedByDefault
        c.find('.js-show-all-inlines').on('click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Reply menu'])
            @unfoldAllChildBlips()
        ).on('mousedown', (e) =>
            e.preventDefault()
            e.stopPropagation()
        )
        c.find('.js-hide-all-inlines').on('click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Reply menu'])
            @foldAllChildBlips()
        ).on('mousedown', (e) =>
            e.preventDefault()
            e.stopPropagation()
        )
        @_copyBlipButton = c.find('.js-copy-blip-button')[0]
        @_pasteAtCursorButton = c.find('.js-paste-at-cursor-button')[0]
        @_pasteAfterBlipButton = c.find('.js-paste-after-blip-button')[0]
        @_showHideEditButtons()
        @_initCopyPasteBlipButtons()

    _initReplyButton: ->
        @_replyButton = $(@_blipContainer).find('.js-blip-reply-button')[0]
        $(@_replyButton).bind 'click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Re in blip menu'])
            @insertReplyBlip()

    insertReplyBlip: ->
        @_parent.initInsertInlineBlip(yes, {}, BlipThread.getBlipThread(@_blipContainer))
        @_waveViewModel.getView().runCheckRange() unless BrowserSupport.isWebKit()

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
                @_waveViewModel.updateUserInfo(user)

    _initEditor: (content) ->
        ###
        Инициализирует редактор содержимого блипа
        ###
        c = $(@_blipContainer)
        @_editorNode = c.find('.js-editor-container')[0]
        isRoot = if @_parent then false else true
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
        @_editor = new Editor(lightBoxId, EditorConfig, functions, not isRoot)
        @_editor.on 'focused', =>
            return if @_isActive
            e = BrowserEvents.createCustomEvent(BrowserEvents.C_FOCUS_EVENT, yes, no)
            e.blip = @
            @_blipContainer.dispatchEvent(e)
        @_editor.on 'mousedown', =>
            e = BrowserEvents.createCustomEvent(BrowserEvents.C_EDITOR_MOUSE_DOWN_EVENT, yes, no)
            e.target = @_editorNode
            @_blipContainer.dispatchEvent(e)
        @_editor.on 'ops', @_processEditorChanges
        @_editor.on 'error', (e) =>
            @_editor.setEditable(no)
            @_editor.removeListener('ops', @_processEditorChanges)
            @_blipProcessor.showPageError(e)
        @_editor.on 'copy', =>
            @renderRecursively()
        @_editor.initContent()
        @updatePermission()
        editorContainer = @_editor.getContainer()
        @_editorNode.appendChild(editorContainer)
        DOM.addClass(editorContainer, 'container-blip-editor') unless @_parent

    _initCopyPasteBlipButtons: ->
        @_copyBlipButton.addEventListener('click', @_handleCopyBlipButton, no)
        @_pasteAtCursorButton.addEventListener('mousedown', @_handlePasteAtCursorButton, no)
        @_pasteAfterBlipButton.addEventListener('click', @_handlePasteAfterBlipButton, no)

    _handleCopyBlipButton: =>
        _gaq.push(['_trackEvent', 'Blip usage', 'Copy blip'])
        @renderRecursively()
        @_parent.getEditor().copyElementToBuffer(@_blipContainer)

    _handlePasteAtCursorButton: =>
        _gaq.push(['_trackEvent', 'Blip usage', 'Paste blip', 'At cursor'])
        @_editor.pasteBlipFromBufferToCursor()

    _handlePasteAfterBlipButton: =>
        _gaq.push(['_trackEvent', 'Blip usage', 'Paste blip', 'After blip'])
        @_parent.getEditor().pasteBlipFromBufferAfter(@_blipContainer)

    _getContent: =>
        @_model.getSnapshotContent()

    _createDOM: (ts) ->
        ###
        Создает все необходимые для отображения сообщения DOM-ноды
        ###
        c = $(@_blipContainer)
        params =
            isNotInRootThread: @__isNotInRootThread
            isRoot: not @_parent
            datetime: formatDate ts
            fullDatetime: formatDate(ts, true)
            isAnonymous: !window.loggedIn
        c.addClass('blip-container')
        if not @_parent
            c.prepend(renderBlip(params))
        else
            c.append(renderBlip(params))
        @_editorNode = c.find('.js-editor-container')[0]
        @_menuContainer = c.find('.js-blip-menu-container')[0] or null
        @_menu = c.find('.js-blip-menu')[0] or null
        @_initReplyButton()

    recursivelyUpdatePermission: ->
        @updatePermission()
        for _, blip of @_childBlips
            blip.getView().recursivelyUpdatePermission()

    updatePermission: ->
        role = @_waveViewModel.getRole()
        switch role
            when ROLE_OWNER then @_permission = EDIT_PERMISSION
            when ROLE_EDITOR then @_permission = EDIT_PERMISSION
            when ROLE_COMMENTATOR
                if @_model.getAuthorId() is window.userInfo.id
                    @_permission = EDIT_PERMISSION
                else
                    @_permission = COMMENT_PERMISSION
            else @_permission = READ_PERMISSION
        return if not @_rendered
        @_editor.setPermission(@_permission)
        if @_permission is EDIT_PERMISSION
            $(@_blipContainer).removeClass('non-editable')
        else
            $(@_blipContainer).addClass('non-editable')
        @_showHideEditButtons()

    getPermission: -> @_permission

    hasEditPermission: ->
        # TODO: bad function, remove it
        @_permission is EDIT_PERMISSION

    _processFocusInEvent: (event) =>
        @_focused = yes
        @_markAsRead()
        event.stopPropagation()

    _processFocusOutEvent: (event) =>
        @_focused = no
        @_markAsRead()
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

    _markAsRead: (update = yes, sendToServer = yes) ->
        @__hideUnreadIndicator()
        @_waveViewModel.setBlipAsRead(@_model.serverId) if @_model.serverId
        modelVersion = @_model.getVersion()
        return @_lastReadVersion = modelVersion if not update
        return if @_lastReadVersion is modelVersion
        @_lastReadVersion = modelVersion
        @_model.isRead = true
        if sendToServer
            @_blipProcessor.updateBlipReader(@_blipViewModel)
            @_waveViewModel.checkBlipSetAsRead(@_model.serverId) if @_model.serverId

    markAsRead: (sendToServer = yes) -> @_markAsRead(true, sendToServer)

    _markAsUnread: ->
        @__showUnreadIndicator()
        @_model.isRead = false
        @_waveViewModel.setBlipAsUnread(@_model.serverId) if @_model.serverId

    initInsertInlineBlip: (insertIntoEditor = yes, params = {}, thread = null) ->
        ###
        Начинает вставку вложенного сообщения
        @param insertToEnd: boolean, нужно ли вставить дочерний блип в конец
        @return: blipViewModel
        ###
        container = @_getChildBlipContainer()
        blipViewModel = require('./processor_mobile').instance.createBlip(@_waveViewModel, container, params, @_blipViewModel)
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
        # TODO: if occurred during paste event all blips will be editable
        blipViewModel.setEditable(yes)
        blipViewModel.getView().focus()
        e = BrowserEvents.createCustomEvent(BrowserEvents.C_BLIP_CREATE_EVENT, yes, yes)
        e.blip = blipViewModel
        @_blipContainer.dispatchEvent(e)
        return blipViewModel

    _processEditorChanges: (ops) =>
        @submitOps(ops)

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

    _getRecipient: (args...) =>
        canDelete = (id) =>
            @_permission is EDIT_PERMISSION or
                id is window.userInfo?.id
        canConvert = (id) =>
            @_permission is EDIT_PERMISSION
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

    setEditable: (@_editable) ->
        ###
        Устанавливает режим редактирования
        @param editable: bool
        ###
        @_editable = no unless @_parent
        @_editor.setEditable(@_editable)

    focus: ->
        ###
        Устанавливает курсор в текущий редактор
        ###
        @_markAsRead()
        @_editor?.focus()

    markActive: =>
        @_isActive = yes
        $(@_blipContainer).addClass('active')
        @_markAsRead()
        @_initMenu() if not @_blipMenu and @_parent

    unmarkActive: =>
        @_isActive = no
        $(@_blipContainer).removeClass('active')

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

    _remove: (event) =>
        ###
        Удаляет это сообщение
        ###
        event.stopPropagation()
        if window.confirm("Delete reply?")
            _gaq.push(['_trackEvent', 'Blip usage', 'Delete blip'])
            @_parent.removeChild(@_model.id)

    _hideButton: (button) ->
        $(button).addClass('hidden')
        $(button).prev().addClass('hidden')

    _showButton: (button) ->
        $(button).removeClass('hidden')
        $(button).prev().removeClass('hidden')

    _showHideEditButtons: ->
        if @_permission is EDIT_PERMISSION
            @_showButton(@_deleteButton)
            @_showButton(@_isFoldedByDefaultBox)
        else
            @_hideButton(@_deleteButton)
            @_hideButton(@_isFoldedByDefaultBox)
        if @_permission in [EDIT_PERMISSION, COMMENT_PERMISSION]
            @_showButton(@_replyButton)
            @_showButton(@_pasteAtCursorButton)
            @_showButton(@_pasteAfterBlipButton)
        else
            @_hideButton(@_replyButton)
            @_hideButton(@_pasteAtCursorButton)
            @_hideButton(@_pasteAfterBlipButton)

    getContainer: ->
        ###
        Возвращает контейнер, в котором содержится сообщение
        @return: HTMLNode
        ###
        @_blipContainer

    _newChildBlip: (serverBlipId, container, callback) ->
        ###
        Создает объект вложенного блипа
        @param serverBlipId: string, идентификатор блипа
        @param container: HTMLNode, нода, в которой будет сообщение
        @param callback: function
            callback(BlipViewModel)
        ###
        require('./processor_mobile').instance.openBlip(@_waveViewModel, serverBlipId, container, @_blipViewModel, callback)

    applyisFoldedByDefaultOp: (op) ->
        ###
        Обновляет пункт меню "Свернут по умолчанию" по чужой операции
        ###
        if op.oi then $(@_isFoldedByDefaultBox).addClass('active') else $(@_isFoldedByDefaultBox).removeClass('active')

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
        if not @_editor
            @_processBlipOps(ops)
        else
            user = null
            if meta? and meta.user? and not @_isMyMeta(meta)
                u = @_waveViewModel.getUser(meta.user)
                if u.isLoaded() and (name = u.getRealName() or u.getEmail())
                    user = {name: name, id: u.getId()}
            @_editor.applyOps(ops, shiftCursor, user)
        return if @_focused
        if meta? and @_isMyMeta(meta)
            @_markAsRead()
        else if @_opsSetUnreadIndicator(ops)
            @_markAsUnread()

    _processBlipOps: (ops) ->
        changedBlipIds = {}
        haveChanged = false
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

    _setIsFoldedByDefault: =>
        ###
        Устанавливает поле "isFoldedByDefault" в модели равным галочке "Свернут по умолчанию"
        ###
        folded = $(@_isFoldedByDefaultBox).hasClass('active')
        if folded
            $(@_isFoldedByDefaultBox).removeClass('active')
        else
            _gaq.push(['_trackEvent', 'Blip usage', 'Set always hide'])
            $(@_isFoldedByDefaultBox).addClass('active')
        @_model.setIsFoldedByDefault(not folded)

    setFoldedByDefault: (folded) ->
        @_model.setIsFoldedByDefault(folded)
        if folded
            $(@_isFoldedByDefaultBox).addClass('active')
        else
            $(@_isFoldedByDefaultBox).removeClass('active')

    getChildBlipByServerId: (serverBlipId) ->
        ###
        Возвращает объект со вложенными блипами
        @return: BlipViewModel|null
        ###
        childBlipId = @_getChildBlipId(serverBlipId)
        return null if not childBlipId?
        @_childBlips[childBlipId]

    destroy: ->
        super()
        @_copyBlipButton?.removeEventListener('click', @_handleCopyBlipButton, no)
        @_pasteAtCursorButton?.removeEventListener('mousedown', @_handlePasteAtCursorButton, no)
        @_pasteAfterBlipButton?.removeEventListener('mousedown', @_handlePasteAfterBlipButton, no)
        @removeAllListeners()
        delete @_blipViewModel
        @_waveViewModel.setBlipAsRemoved(@_model.serverId) if @_model.serverId
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

    getViewModel: ->
        #TODO: hack
        @_blipViewModel

MicroEvent.mixin(BlipView)
module.exports =
    BlipView: BlipView
