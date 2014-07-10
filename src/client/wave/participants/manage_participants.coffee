renderParticipant = require('../../user/template').renderParticipant
{renderManageParticipantsForm} = require('./template')
compareContacts = require('../../user/utils').compareContactsByNameAndEmail
{ROLES, ROLE_NO_ROLE, ROLE_OWNER} = require('./constants')
{PopupContent} = require('../../popup')

class ManageParticipantsForm
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_participantsData, @_removeParticipants, @_canRemove, @_createWaveWithParticipants, @_changeRole, @_canEdit, @_hideCreateTopicForSelectedButton, gDriveShareUrl) ->
        params = {roles: ROLES, skipRole: ROLE_OWNER, isAnonymous: !window.loggedIn, gDriveShareUrl}
        @_showParticipantsForm = $(renderManageParticipantsForm(params))
        @_resultsContainer = @_showParticipantsForm.find('.js-autocomplete-results')
        @_users = @_getParticipantsData()
        @_initParticipantsInput()
        @_initUserSelection()
        @_initButtons()
        @_showList()

    _initParticipantsInput: ->
        @_showParticipantsInput = @_showParticipantsForm.find('.js-showing-participants-id')
        @_showParticipantsInput.keyup(@_filterParticipantsHandler)

    _initUserSelection: ->
        @_selectedCountBlock = @_showParticipantsForm.find('.js-selected-count span')
        @_selectedUsersCount = 0
        @_selectAll = @_showParticipantsForm.find('.js-select-all-checkboxes')
        @_selectAll.click(@_selectAllHandler)
        @_resultsContainer.on('click', '.js-results-list li', @_participantSelectHandler)

    _initButtons: ->
        @_deleteButton = @_showParticipantsForm.find('.js-remove-selected')
        @_deleteButton.click(@_deleteSelectedHandler)
        @_createTopicForSelectedButton = @_showParticipantsForm.find('.js-create-topic-for-selected')
        @_createTopicForSelectedButton.click(@_createForSelectedHandler)
        @hideCreateTopicForSelectedButton() if @_hideCreateTopicForSelectedButton
        @_changeRoleSelect = @_showParticipantsForm.find('.js-participant-role-select')
        @_changeRoleSelect.selectBox().change(@_changeRoleHandler)
        @_disableButtons()

    _updateButtonsState: ->
        selectedParticipants = @_getSelectedParticipants()
        return @_disableButtons() if not selectedParticipants.length
        @_enableButtons()
        canRemove = canEdit = false
        for p in selectedParticipants
            canRemove = true if @_canRemove(p.id)
            canEdit = true if @_canEdit(p.id)
        @_deleteButton.attr('disabled', 'disabled') if not canRemove
        @_changeRoleSelect.selectBox('disable') if not canEdit
        commonRoleId = null
        for p in selectedParticipants
            commonRoleId ?= if p.roleId is ROLE_OWNER then -1 else p.roleId
            commonRoleId = -1 if commonRoleId isnt p.roleId
        @_changeRoleSelect.selectBox('value', commonRoleId)

    _enableButtons: ->
        @_deleteButton.removeAttr('disabled')
        @_createTopicForSelectedButton.removeAttr('disabled')
        @_changeRoleSelect.selectBox('enable')

    _disableButtons: ->
        @_deleteButton.attr('disabled', 'disabled')
        @_createTopicForSelectedButton.attr('disabled', 'disabled')
        @_changeRoleSelect.selectBox('disable')

    prepareShow: ->
        @_updateButtonsState()
        @_showParticipantsForm.show()
        @_showParticipantsInput.select()

    hideCreateTopicForSelectedButton: ->
        @_createTopicForSelectedButton.hide()
        @_deleteButton.removeClass('remove-selected')
    
    showCreateTopicForSelectedButton: ->
        @_createTopicForSelectedButton.show()
        @_deleteButton.addClass('remove-selected')
    
    _deleteSelectedHandler: =>
        selectedParticipants = @_getSelectedParticipants()
        canRemove = []
        cantRemove = []
        for sp in selectedParticipants
            if not @_canRemove(sp.id)
                cantRemove.push(sp)
            else
                canRemove.push(sp)
        message = "Delete #{canRemove.length} users?"
        if cantRemove.length
            if cantRemove.length <= 5
                message += " Users #{(u.email for u in cantRemove).join(', ')} will not be deleted"
            else
                message += " #{cantRemove.length} users will not be deleted"
        if window.confirm(message)
            @_removeParticipants((u.id) for u in canRemove)
            @_showList()

    _changeRoleHandler: =>
        roleId = @_changeRoleSelect.val() - 0
        return if roleId is -1
        selectedParticipants = @_getSelectedParticipants()
        canEdit = []
        cantEdit = []
        for p in selectedParticipants
            if @_canEdit(p.id)
                canEdit.push(p)
            else
                cantEdit.push(p)
        changeRole = =>
            for sp in canEdit
                @_changeRole(sp.id, roleId)
        return changeRole() if not cantEdit.length
        if window.confirm("Cannot change #{(u.email for u in cantEdit).join(', ')} role, change role anyway?")
            changeRole()

    _createForSelectedHandler: =>
        selectedParticipants = @_getSelectedParticipants()
        userIds = []
        hasSelf = false
        for sp in selectedParticipants
            userIds.push(sp.id)
            hasSelf ||= sp.id is window.userInfo.id
        userIds.push(window.userInfo.id) if not hasSelf
        _gaq.push(['_trackEvent', 'Topic creation', 'Create topic', 'With this team', userIds.length])
        @_createWaveWithParticipants(userIds)
        $(document).off 'click.manageParticipants'

    _getParticipantsData: ->
        waveUsers = @_waveViewModel.getParticipants()
        users = []
        for user in waveUsers
            curUser =
                searchString: user.getSearchString()
                data: user.getDataForAutocomplete()
                checked: false
                show: true
            curUser.data.roleId = @_getUserRole(user.getId())
            users.push(curUser)
        users.sort(@_compareContacts)
        return users

    _compareContacts: (a, b) -> compareContacts(a.data, b.data)
    
    _checkParticipantInput: (checked) ->
        if checked
            @_selectedUsersCount += 1
            @_selectAll.attr('checked', true) if @_selectedUsersCount == @_users.length
        else
            @_selectedUsersCount -= 1
            @_selectAll.removeAttr('checked')
        @_selectedCountBlock.text(@_selectedUsersCount)
        @_updateButtonsState()

    _showList: ->
        @_resultsList?.remove()
        @_selectedUsersCount = 0
        @_resultsList = $('<ul></ul>').hide().addClass('js-results-list results-list')
        for user in @_users
            if user.show
                @_resultsList.append($('<li>' + renderParticipant(user) + '</li>').data('id', user.data.id))
            @_selectedUsersCount += 1 if user.checked
        @_resultsContainer.append(@_resultsList)
        @_resultsList.show()
        @_selectedCountBlock.text(@_selectedUsersCount)

    _participantSelectHandler: (event) =>
        id = $(event.currentTarget).data('id')
        for user in @_users
            continue if id isnt user.data.id
            input = $(event.currentTarget).find('input')
            if input[0] == event.target
                checked = input.attr('checked') == 'checked'
                user.checked = checked
                @_checkParticipantInput(checked)
            else if input.attr('checked') == 'checked'
                input.removeAttr('checked')
                user.checked = false
                @_checkParticipantInput(user.checked)
            else
                input.attr('checked', true)
                user.checked = true
                @_checkParticipantInput(user.checked)
            return

    _filterParticipants: (filterString) ->
        checked = true
        for user in @_users
            if user.searchString.search(filterString) == -1
                user.show = false
            else
                user.show = true
                checked = false if not user.checked
        if checked
            @_selectAll.attr('checked', true)
        else
            @_selectAll.removeAttr('checked')

    _filterParticipantsHandler: (event) =>
        currentString = $(event.currentTarget).val().toLowerCase()
        @_filterParticipants(currentString)
        @_showList()

    _selectAllHandler: (event) =>
        input = $(event.currentTarget)
        if input.attr('checked') == 'checked'
            @_resultsList.find('li input').attr('checked', true)
            for user in @_users 
                if user.show and not user.checked
                    user.checked = true
                    @_checkParticipantInput(user.checked)
        else
            @_resultsList.find('li input').removeAttr('checked')
            for user in @_users
                if user.show and user.checked
                    user.checked = false
                    @_checkParticipantInput(user.checked)
    
    _getSelectedParticipants: ->
        (u.data for u in @_users when u.checked)

    removeParticipant: (user) ->
        id = user.id
        for user in @_users
            if user.data.id == id
                @_users.splice(@_users.indexOf(user), 1)
                break
        listNodes = @_resultsList.find('li')
        @_showList()

    _getUserRole: (userId) ->
        for p in @_participantsData
            continue if p.id isnt userId
            return p.role

    updateParticipants: (users) ->
        for user in users
            for u in @_users when u.data.id == user.getId()
                u.data = user.getDataForAutocomplete()
                u.data.roleId = @_getUserRole(u.data.id)
                u.searchString = user.getSearchString()
                break
        @_filterParticipants(@_showParticipantsInput.val())
        @_showList()
        
    addParticipant: (participant) ->
        if participant.role != ROLE_NO_ROLE
            user = @_waveViewModel.getUser(participant.id, yes)
            userData =
                searchString: user.getSearchString()
                data: user.getDataForAutocomplete()
                checked: false
                show: false
            userData.data.roleId = participant.role
            @_users.push(userData)
    
    destroy: ->
        @_showParticipantsForm.remove()
        @_changeRoleSelect.selectBox('detach')
        @_resultsContainer.remove()
        delete @_waveViewModel
        delete @_participantsData
        delete @_removeParticipants
        delete @_canRemove
        delete @_createWaveWithParticipants
        delete @_changeRole
        delete @_canEdit
        delete @_hideCreateTopicForSelectedButton

    getContainer: -> @_showParticipantsForm


class ManageParticipantsPopup extends PopupContent
    ###
    Оболочка над ManageParticipantsForm, нужна, чтобы не пересоздавать форму при каждом открытии.
    ###
    constructor: (getForm) ->
        @_manageParticipantsForm = getForm()

    destroy: ->
        # Отвязываемся от родителя сами, чтобы popup не убрал все события
        @_manageParticipantsForm.getContainer().detach()
        delete @_manageParticipantsForm

    shouldCloseWhenClicked: (element) ->
        # Не закрываемся при клике на dropdown со списком ролей
        return $(element).closest('.js-participant-role-select-selectBox-dropdown-menu').length == 0

    getContainer: ->
        # Обновляем внешний вид формы для показа
        @_manageParticipantsForm.prepareShow()
        return @_manageParticipantsForm.getContainer()


module.exports = {ManageParticipantsForm, ManageParticipantsPopup}