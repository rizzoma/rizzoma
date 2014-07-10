###
Класс для выбора набора участников из списка контактов или вводом e-mail.
###
{renderContactPicker, renderContactList, renderParticipants} = require('./template')
{compareContactsByNameAndEmail, getContactSources} = require('../user/utils')
DomUtils = require('../utils/dom')
{KeyCodes} = require('../utils/key_codes')
{WaveWarning} = require('../wave/notification/warning')
{isEmail} = require('../utils/string')
contactsConstants = require('../../share/contacts/constants')
{renderContactsSyncButton} = require('../wave/participants/add_form')
MicroEvent = require('../utils/microevent')

{popup} = require('../popup')
{UserPopup, setUserPopupBehaviour} = require('../popup/user_popup')
{renderBottomPopup} = require('../wave/participants/template')

DEFAULT_PARTICIPANTS_STRING_LENGTH = 8
SHOW_CONTACTS_BY_DEFAULT = 100

compareContacts: (a, b) -> compareContactsByNameAndEmail(a.data, b.data)


class ParticipantPopup extends UserPopup
    _init: (user, @_removeParticipant) ->
        super(user)

    bottomBlockRender: ->
        ###
        Рендерим блок с ссылкой на удаление
        ###
        bottomBlock = $(@getContainer()).find('.js-user-popup-menu-remove-block')
        bottomBlock.append(renderBottomPopup({canRemove: true})) if @_user.toObject().email != window.userInfo.email
        delLink = $(@getContainer()).find('.js-delete-from-wave')
        delLink.bind 'click', =>
            @_removeParticipant(@_user.toObject().email)
            popup.hide()

    destroy: ->
        super()
        delete @_removeParticipant


class ContactPicker

    SCROLL_OFFSET = -90

    constructor: (@_container, @_waveProcessor, @_params) ->
        @_userContacts = []
        user =
            toObject: ->
                name: window.userInfo.name
                email: window.userInfo.email
                avatar: window.userInfo.avatar
                initials: window.userInfo.initials
        @_participants = [user]
        @_params.participantsStringLength ?= DEFAULT_PARTICIPANTS_STRING_LENGTH
        @__createDOM()
        @_notificationsContainer = @_params.notificationContainer
        @_initSyncButtons()
        @_initContactList()
        @_initParticipantInput()
        @__renderParticipants('set')

    __createDOM: ->
        $(@_container).append(renderContactPicker(@_params))
        $(@_container).find('.js-contact-picker-email').placeholder?()
        if @_params.participantsContainer
            @_$participantsContainer = $(@_params.participantsContainer)
        else
            div = document.createElement('div')
            div.className = 'js-contact-picker-participants contact-picker-participants'
            $(@_container).prepend(div)
            @_$participantsContainer = $(@_container).find('.js-contact-picker-participants')
            @_$participantsContainer.show()

    _initSyncButtons: ->
        @_$syncContactsContainer = $(@_container).find('.js-contact-picker-sync-contacts')
        @_renderSyncBlock()
        @_$syncContactsContainer.on 'click', 'button', (e) =>
            source = $(e.currentTarget).attr('source')
            @_params.contactsSyncStart?(source)
            @_waveProcessor.initContactsUpdate source, e.screenX-630, e.screenY, =>
                @updateContacts()
                @_params.contactsSyncFinish?(source)

    _renderSyncBlock: ->
        contactSources = getContactSources(@_userContacts)
        @_$syncContactsContainer.empty()
            .append(@_renderGoogleContactsSyncButton(contactSources))
            .append('<br/>')
            .append(@_renderFacebookContactsSyncButton(contactSources))

    _renderGoogleContactsSyncButton: (contactSources) ->
        params =
            source: 'google'
            hasContacts: contactSources.google
            sourceConstant: contactsConstants.SOURCE_NAME_GOOGLE
        return renderContactsSyncButton(params)

    _renderFacebookContactsSyncButton: (contactSources) ->
        params =
            source: 'facebook'
            hasContacts: contactSources.facebook
            sourceConstant: contactsConstants.SOURCE_NAME_FACEBOOK
        return renderContactsSyncButton(params)

    _initContactList: ->
        @_$contactsContainer = $(@_container).find('.js-contact-picker-contacts')
        @_$contactsContainer.on 'mouseover', '.js-contact-picker-contact-item', (event) =>
            @_$contactsContainer.find('.js-contact-picker-contact-item').removeClass('active')
            $(event.currentTarget).addClass('active')
        @_$contactsContainer.on('click', '.js-contact-picker-contact-item', @_handleAddParticipant)
        $(@_container).find('.js-contact-picker-add-participant').click(@_processAddButtonClick)

    _updateContactList: ->
        @_showedContacts = []
        for c in @_userContacts
            @_showedContacts.push(c) if c.showed
        @_initContactScroll()
        @_$contactsContainer.html(renderContactList({contacts: @_showedContacts.splice(0, SHOW_CONTACTS_BY_DEFAULT)}))
        headItem = @_$contactsContainer.find('.js-contact-picker-contact-item')[0]
        if headItem
            $(headItem).addClass('active')
            @_$contactsContainer.scrollTop(0)

    _initContactScroll: ->
        @_$contactsContainer.off 'scroll.renderContacts'
        @_$contactsContainer.on 'scroll.renderContacts', =>
            @_$contactsContainer.append(renderContactList({contacts: @_showedContacts.splice(0, SHOW_CONTACTS_BY_DEFAULT)}))
            if @_showedContacts.length == 0
                @_$contactsContainer.off 'scroll.renderContacts'

    _handleAddParticipant: =>
        ###
        Добавляет участника, если это возможно (введен верный e-mail либо выбран участник из списка).
        Если участник был добавлен, возвращает true.
        ###
        $activeElem = @_$contactsContainer.find('.active')
        if $activeElem.length == 1
            email = $activeElem.find('.js-email').text().slice(1,-1)
        else
            email = @_participantInput.val()
        if isEmail(email)
            @_addParticipant(email)
            return true
        @__showWarning('Enter valid e-mail')
        return false

    _processAddButtonClick: =>
        if @_handleAddParticipant()
            @_participantInput.val('')
            @_filterContacts('')

    _addParticipant: (email) ->
        email = email.toLowerCase()
        user = @_getUserByEmail(email) || @_getUserStub(email)
        for p in @_participants
            return if p.toObject().email == user.data.email
        user.toObject = ->
            name: user.data.name
            email: user.data.email
            avatar: user.data.avatar
            initials: if user.data.initials? then user.data.initials else ''
        @_participants.push(user)
        $(@_notificationsContainer).find('.js-wave-warning').remove()
        @__renderParticipants('add')
        @emit('add-participant', email)

    _removeParticipant: (email) =>
        for p in @_participants
            if p.toObject().email == email
                @_participants.splice(@_participants.indexOf(p), 1)
                break
        @__renderParticipants('remove')
        @emit('remove-participant', email)

    _getUserByEmail: (email) =>
        for c in @_userContacts
            if c.data.email.toLowerCase() is email
                return c
        return null

    _getUserStub: (email) ->
        searchString: email
        data:
            name: email
            email: email
            avatar: '/s/img/user/unknown.png'

    __renderParticipants: (action) ->
        ###
        Обновляет список участников
        @param action: string, действие, после которого происходит обновление
        ###
        params =
            participants: (p.toObject() for p in @_participants)
            participantsStringLength: @_params.participantsStringLength
        @_$participantsContainer.html(renderParticipants(params))
        $(@_$participantsContainer).find('.js-contact-picker-participant').each (index, element) =>
            setUserPopupBehaviour(element, ParticipantPopup, @_participants[index], @_removeParticipant)

    _initParticipantInput: ->
        @_participantInput = $(@_container).find('.js-contact-picker-email')
        @_participantInput.on('keydown', @_participantInputKeydownHandler)
        @_participantInput.on('keyup', @_participantInputKeyupHandler)
        @_participantInput.on('paste', => @_filterContacts(@_participantInput.val().toLowerCase()))

    _participantInputKeydownHandler: (event) =>
        return if event.ctrlKey or event.altKey
        switch event.keyCode
            when KeyCodes.KEY_UP then @_focusPrev()
            when KeyCodes.KEY_DOWN then @_focusNext()
            when KeyCodes.KEY_ENTER then @_processAddButtonClick()

    _participantInputKeyupHandler: (event) =>
        return if event.ctrlKey or event.altKey or event.keyCode in [KeyCodes.KEY_UP, KeyCodes.KEY_DOWN]
        @_filterContacts(@_participantInput.val().toLowerCase())

    _focusNext: ->
        $selectedItem = @_$contactsContainer.find('.js-contact-picker-contact-item.active')
        $nextAfterSelectedItem = $selectedItem.next('.js-contact-picker-contact-item')
        if $nextAfterSelectedItem.length > 0
            $selectedItem.removeClass('active')
            $nextAfterSelectedItem.addClass('active')
            DomUtils.scrollTargetIntoView($nextAfterSelectedItem[0], @_$contactsContainer[0], true, SCROLL_OFFSET)

    _focusPrev: ->
        $selectedItem = @_$contactsContainer.find('.js-contact-picker-contact-item.active')
        $prevBeforeSelectedItem = $selectedItem.prev('.js-contact-picker-contact-item')
        if $prevBeforeSelectedItem.length > 0
            $selectedItem.removeClass('active')
            $prevBeforeSelectedItem.addClass('active')
            DomUtils.scrollTargetIntoView($prevBeforeSelectedItem[0], @_$contactsContainer[0], true, SCROLL_OFFSET)

    _filterContacts: (currentString) =>
        return if not @_userContacts.length
        for user in @_userContacts
            if user.searchString.search(currentString) == -1
                user.showed = false
            else
                user.showed = true
        @_updateContactList()

    updateContacts: ->
        @_waveProcessor.getUserContacts (err, users) =>
            return console.warn('Failed to load contacts', err) if err or not users
            @_userContacts = ({searchString: user.getSearchString(), data: user.getDataForAutocomplete(), showed: true} for user in users)
            @_renderSyncBlock()
            @_$contactsContainer.show() if @_userContacts.length > 0
            @_userContacts.sort(@_compareContacts)
            @_updateContactList()

    __showWarning: (message) ->
        warnings = $(@_notificationsContainer).find('.js-wave-warning')
        if warnings.length >= 5
            $(warnings[0]).remove()
        $(@_notificationsContainer).append((new WaveWarning(message)).getContainer())
        $(window).trigger('resize')
        console.warn(message)

    setContactsHeight: (height)->
        @_$contactsContainer.height(height)

    getParticipants: ->
        @_participants

    setParticipants: (participants) ->
        @_participants = participants
        @__renderParticipants('set')

    getEmails: ->
        (p.toObject().email for p in @_participants)
MicroEvent.mixin(ContactPicker)


module.exports = {ContactPicker}