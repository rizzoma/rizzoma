{renderParticipantsContainer, renderParticipant, renderBottomPopup} = require('./template')
popup = require('../../popup').popup
setUserPopupBehaviour = require('../../popup/user_popup').setUserPopupBehaviour
UserPopup = require('../../popup/user_popup').UserPopup
{ManageParticipantsForm, ManageParticipantsPopup} = require('./manage_participants')
{normalizeEmail} = require('../../utils/string')
{ROLES, ROLE_OWNER, ROLE_EDITOR, ROLE_NO_ROLE} = require('./constants')

canEditParticipant = (waveViewModel, userId) ->
    waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR] and
        (userId isnt window.userInfo?.id) and
        waveViewModel.getModel().getRole(userId) isnt ROLE_OWNER

canRemoveParticipant = (waveViewModel, userId) ->
    return true if userId is window.userInfo?.id
    return false if waveViewModel.getModel().getRole(userId) is ROLE_OWNER
    waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR]

class ParticipantPopup extends UserPopup
    _init: (user, @_canEdit, @_canRemove, @_getRole, @_changeParticipantRole, @_removeParticipant) ->
        super(user)
    
    bottomBlockRender: ->
        ###
        Рендерим блок с ссылкой на удаление
        ###
        $c = $(@getContainer())
        bottomBlock = $c.find('.js-user-popup-menu-remove-block')
        params =
            user: @_user
            roleId: @_getRole()
            roles: ROLES
            skipRole: ROLE_OWNER
            canRemove: @_canRemove()
        bottomBlock.append(renderBottomPopup(params))
        delLink = $c.find('.js-delete-from-wave')
        delLink.bind 'click', (event) =>
            if window.confirm "Delete user from this topic: #{@_user.getName()}?"
                @_removeParticipant(@_user.getId())
                popup.hide()
        @_roleSelect = $c.find('.js-role-select')[0]
        $(@_roleSelect).selectBox().change =>
            @_changeParticipantRole(@_user.getId(), $(@_roleSelect).val() - 0)
        if not @_canEdit()
            $(@_roleSelect).selectBox('disable')

    shouldCloseWhenClicked: (element) ->
        return $(element).closest('.role-select-selectBox-dropdown-menu').length == 0

    destroy: ->
        $(@_roleSelect).selectBox('destroy')
        delete @_removeParticipant
        super()

class Participants
    LOAD_PARTICIPANTS_COUNT = 20
    MAX_SHOWED_PARTICIPANTS = 5

    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_processor, @_modelId, @_participants, @_allowRemove, gDriveShareUrl) ->
        @_createDom(gDriveShareUrl)
        @_initParticipants()
        @_waveViewModel.on('usersInfoUpdate', @_updateParticipantsInfo)
        @_hideCreateTopicForSelectedButton = false

    _createDom: (gDriveShareUrl) ->
        @_container = document.createElement('div')
        $container = $(@_container)
        $container.append(renderParticipantsContainer())
        @_participantsContainer = $container.find('.js-participant-container')[0]
        @_moreParticipantsButton = $(@_container).find('.js-show-more-participants')
        @_manageForm = null
        @_roleSelect = $container.find('.js-participant-role-select')
        @_roleSelect.selectBox()
        getManageForm = =>
            @_manageForm ?= new ManageParticipantsForm(@_waveViewModel, @_participants, @_removeParticipants,
                    @_canRemoveParticipant, @_createWaveWithParticipants, @_changeParticipantRole,
                    @_canEditParticipant, @_hideCreateTopicForSelectedButton, gDriveShareUrl)
            return @_manageForm
        setUserPopupBehaviour(@_moreParticipantsButton, ManageParticipantsPopup, getManageForm)

    _getParticipantsIds: (checkRole = no) ->
        participantIds = []
        for participant in @_participants
            continue if checkRole and participant.role == ROLE_NO_ROLE
            participantIds.push(participant.id)
        participantIds

    _initParticipants: ->
        # Делаем копию, т.к. будем менять
        @_participants = JSON.parse(JSON.stringify(@_participants))
        @_users = @_waveViewModel.getUsers(@_getParticipantsIds(yes))
        i = 0
        for index, participant of @_participants
            for user in @_users
                continue if user.getId() isnt participant.id
                @_insertParticipant(index, user, yes) if participant.role != ROLE_NO_ROLE
                i += 1 if participant.role != ROLE_NO_ROLE
                participant.showed = true
                break
            break if i == LOAD_PARTICIPANTS_COUNT
        return if not @_waveViewModel.haveEmails()
        # Обновим данные для закешированных пользователей, у которых нет e-mail
        userIdsWithoutEmails = (u.getId() for u in @_users when not u.getEmail())
        return if not userIdsWithoutEmails.length
        @_waveViewModel.getUsers(userIdsWithoutEmails, true)

    _getNodeIndexByParticipantIndex: (index) ->
        ###
        Возвращает ближайший предшествующий индекс видимой ноды участника топика если он есть
        иначе возвращает -1
        ###
        i = index - 1
        prevShowedIndex = null
        while i >= 0
            if @_participants[i].showed? and @_participants[i].showed
                prevShowedIndex = i
                break
            i -= 1
        if prevShowedIndex != null
            id = @_participants[prevShowedIndex].id
        else
            return -1
        for node in @_participantsContainer.childNodes
            return $(node).index() if id == $(node).data('participantId')

    _insertParticipant: (index, user, init=no) ->
        $container = $(@_participantsContainer)
        if init
            $container.append(renderParticipant(user.toObject()))
            $insertedNode = $container.children().last()
        else
            index = @_getNodeIndexByParticipantIndex(index)
            if index != -1
                $node = $($container.children()[index])
                $node.after(renderParticipant(user.toObject()))
                $insertedNode = $node.next()
            else
                $container.prepend(renderParticipant(user.toObject()))
                $insertedNode = $container.children().first()
        $insertedNode.data('participantId', user.getId())
        @_setParticipantHandlers($insertedNode)

    _getParticipantById: (id) ->
        for participant in @_participants
            return participant if participant.id == id

    _removeNodes: (fromIndex, toIndex) ->
        $nodes = $(@_participantsContainer).children()
        i = fromIndex
        while i <= toIndex
            participant = @_getParticipantById($($nodes[i]).data('participantId'))
            delete participant['showed'] if participant
            $($nodes[i]).remove()
            i += 1

    _addNodes: (countNodes) ->
        participant = @_getParticipantById($(@_participantsContainer).children().last().data('participantId'))
        i = @_participants.indexOf(participant) + 1
        added = 0
        while i < @_participants.length and added < countNodes
            if @_participants[i].role != ROLE_NO_ROLE
                user = @_waveViewModel.getUser(@_participants[i].id)
                @_insertParticipant(i, user, yes)
                @_participants[i].showed = true
                added += 1
            i += 1

    setParticipantsWidth: (@width) ->
        moreButtonWidth = 38
        $(@_participantsContainer).removeAttr('style')
        visibleParticipants = $(@_participantsContainer).find("span")
        participantNode = visibleParticipants[0]
        participantWidth = $(participantNode).outerWidth(true) or 34
        containerWidth = @width - moreButtonWidth
        showedParticipants = (containerWidth - containerWidth%participantWidth)/participantWidth or 0
        showedParticipants = Math.min(showedParticipants, MAX_SHOWED_PARTICIPANTS)
        if visibleParticipants.length > showedParticipants
            @_removeNodes(showedParticipants, visibleParticipants.length - 1)
        else if visibleParticipants.length < showedParticipants
            @_addNodes(showedParticipants - visibleParticipants.length)
        if @_users.length <= showedParticipants
            @_moreParticipantsButton.removeClass('number-shown')
        else
            @_moreParticipantsButton.find('span').text("+#{@_users.length - showedParticipants}")
            @_moreParticipantsButton.addClass('number-shown')
        @_moreParticipantsButton.show()
    
    _setParticipantHandlers: ($participantNode) ->
        user = @_waveViewModel.getUser($participantNode.data('participantId'))
        role = null
        for participant in @_participants
            role = participant.role if participant.id is user.getId()
        getRole = -> role
        canRemove = =>
            @_canRemoveParticipant(user.getId())
        canEdit = =>
            @_canEditParticipant(user.getId())
        setUserPopupBehaviour($participantNode, ParticipantPopup, user, canEdit, canRemove, getRole, @_changeParticipantRole, @_removeParticipant) if user.isLoaded()

    _canEditParticipant: (userId) => canEditParticipant(@_waveViewModel, userId)

    _canRemoveParticipant: (userId) => canRemoveParticipant(@_waveViewModel, userId)

    _updateNodeForParticipant: (user) ->
        $nodes = $(@_participantsContainer).children()
        for node in $nodes
            if $(node).data('participantId') == user.getId()
                $node = $(node)
                $node.after(renderParticipant(user.toObject()))
                $insertedNode = $node.next()
                $insertedNode.data('participantId', user.getId())
                @_setParticipantHandlers($insertedNode)
                $node.remove()
                return

    _updateParticipantsInfo: (userIds) =>
        users = []
        for id in userIds
            for participant in @_participants
                continue if participant.id isnt id
                user = @_waveViewModel.getUser(id)
                users.push(user) if user
                @_updateNodeForParticipant(user) if participant.showed
                break
        @_manageForm?.updateParticipants(users) if users.length

    _add: (participant, index) ->
        @_participants[index...index] = [participant]
        @_participants[index].showed = participant.role isnt ROLE_NO_ROLE
        user = @_waveViewModel.getUser(participant.id)
        @_insertParticipant(index, user) if participant.role isnt ROLE_NO_ROLE
        @_users = @_waveViewModel.getUsers(@_getParticipantsIds(yes))
        @setParticipantsWidth(@width)
        @_manageForm?.addParticipant(participant)

    _remove: (participant, index) ->
        $(@_participantsContainer.childNodes[@_getNodeIndexByParticipantIndex(index) + 1]).remove()
        # Уберем все попапы, кроме формы изменения участников, т.к. они могут содержать уже неверную
        # информацию о пользователе
        popup.hide() if not (popup.getContent() instanceof ManageParticipantsPopup)
        @_manageForm.removeParticipant(participant) if @_manageForm?
        @_participants[index..index] = []
        @_users = @_waveViewModel.getUsers(@_getParticipantsIds(yes))
        @setParticipantsWidth(@width)

    _removeParticipant: (userId) =>
        @_processor.removeParticipant(@_modelId, userId, @_processResponse)

    _removeParticipants: (userIds) =>
        @_processor.removeParticipants @_modelId, userIds, (err, res) =>
            @_processResponse(err, res)

    _changeParticipantRole: (userId, roleId) =>
        @_processor.changeParticipantRole(@_modelId, userId, roleId, @_processResponse)

    _createWaveWithParticipants: (userIds) =>
        @_processor.initCreateWaveWithParticipants(userIds)

    _processResponse: (err) =>
        ###
        Обрабатывает результат изменения участника в топике
        @param err: object|null
        ###
        return if not err
        @_waveViewModel.showWarning(err.message)

    hideCreateTopicForSelectedButton: ->
        @_manageForm.hideCreateTopicForSelectedButton() if @_manageForm
        @_hideCreateTopicForSelectedButton = true
    
    showCreateTopicForSelectedButton: ->
        @_manageForm.showCreateTopicForSelectedButton() if @_manageForm
        @_hideCreateTopicForSelectedButton = false
    
    all: ->
        ###
        Возвращает массив идентификаторов текущих участников волны
        ###
        @_getParticipantsIds(yes)

    getContainer: ->
        @_container

    applyOp: (op) ->
        index = op.p.shift()
        if op.ld
            @_remove op.ld, index
        if op.li
            @_add op.li, index

    destroy: ->
        @_roleSelect.selectBox('destroy')
        @_manageForm?.destroy()
        delete @_manageForm
        delete @_removeParticipant
        delete @_waveViewModel
        delete @_processor
        delete @_participants

module.exports = {Participants, ParticipantPopup, canEditParticipant, canRemoveParticipant}
