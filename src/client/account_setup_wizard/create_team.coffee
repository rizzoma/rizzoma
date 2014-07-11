{renderCreateTeam, renderTeamMember, renderEditTeam, renderBusinessCreateTeam} = require('./template')
ContactPicker = require('../contact_picker').ContactPicker
{ROLE_EDITOR} = require('../wave/participants/constants')
MicroEvent = require('../utils/microevent')
{User} = require('../user/models')


BUSINESS_PANEL_TYPE = 'BUSINESS'
FREE_PANEL_TYPE = 'FREE'

class CreateTeam
    constructor: (@_$container, @_teamType, @_accountSetupWizard, @_topicId) ->
        @_waveProcessor = require('../wave/processor').instance
        @_accountSetupProcessor = require('./processor').instance
        @_participants = []

    renderAndInit: ->
        @_$container.empty()
        if @_contactPicker
            @_participants = @_contactPicker.getParticipants()
        @_$container.append(renderCreateTeam({isBusinessTeamType: @_teamType is BUSINESS_PANEL_TYPE}))
        @_$container.find('input').placeholder?()
        window.setTimeout =>
            @_$container.find('.js-team-name').focus()
        , 0
        @_submitButton = @_$container.find('.js-submit-button button')
        @_init()

    _init: ->
        @_initContactPicker()
        @_$container.find('.js-account-type-item').on 'click', =>
            _gaq.push(['_trackEvent', 'Monetization', 'Return to plan selection'])
            @emit 'returnToAccountSelect'
        @_submitButton.on 'click', =>
            @_$container.find('.js-error-text').hide()
            emails = @_contactPicker.getEmails()
            _gaq.push(['_trackEvent', 'Monetization', 'Create team', @_teamType, emails.length-1])
            if @_teamType is BUSINESS_PANEL_TYPE
                teamName = @_$container.find('.js-team-name').val()
                if teamName.length == 0
                    $errText = @_$container.find('.js-error-text')
                    $errText.show()
                    $errText.animate({opacity: 1}, 500, ->
                        $errText.animate({opacity: 0.4}, 500)
                    )
                    return
                @_submitButton.off()
                @_submitButton.text('Creating...')
                processor = @_accountSetupProcessor
                wizard = @_accountSetupWizard
                waveProcessor = @_waveProcessor
                processor.createTeamByWizard emails, teamName, (err, response) =>
                    console.error err if err
                    wizard.emit('closeAndOpenTopic', response.waveId)
                    processor.forceIsBusinessUpdate()
                    otherEmails = (email for email in emails when email isnt window.userInfo?.email)
                    if window.welcomeTopicJustCreated and otherEmails.length
                        waveProcessor.addParticipants(@_topicId, otherEmails, ROLE_EDITOR, true, ->)
            else if @_teamType is FREE_PANEL_TYPE
                newEmails = (email for email in emails when email isnt window.userInfo.email)
                @_waveProcessor.addParticipants @_topicId, newEmails, ROLE_EDITOR, false, (err, userDatas) ->
                    return if not userDatas
                    countNew = countExisting = 0
                    for userData in userDatas
                        user = new User(null, userData.email, userData.name, userData.avatar)
                        if user.isNewUser() then countNew++
                        else countExisting++
                    _gaq.push(['_trackEvent', 'Topic participants', 'Add participant new', 'By invite tool', countNew]) if countNew > 0
                    _gaq.push(['_trackEvent', 'Topic participants', 'Add participant existing', 'By invite tool', countExisting]) if countExisting > 0
                    _gaq.push(['_trackEvent', 'Invite tool', 'Invite Next click', '', countNew + countExisting])
                    if countNew*countExisting > 0
                        userType = 'new and existing'
                    else if countNew > 0
                        userType = 'new'
                    else
                        userType = 'existing'
                    mixpanel.track("Add participant", {"participant type": userType, "added via": 'By invite tool', "count":countNew+countExisting, "count new":countNew, "count existing":countExisting}) if countNew+countExisting > 0
                @_accountSetupWizard.emit('closeAndOpenTopic', @_topicId)

    _initContactPicker: ->
        contactPickerContainer = @_$container.find('.js-account-wizard-contact-picker-container')[0]
        params =
            participantsStringLength: 1
            contactsSyncStart: (source) -> _gaq.push(['_trackEvent', 'Contacts synchronization', 'Synchronize contacts click', "invite tool #{source}"])
            contactsSyncFinish: (source) -> _gaq.push(['_trackEvent', 'Contacts synchronization', 'Successfull synchronization', "invite tool #{source}"])
            notificationContainer: @_$container.find('.js-invite-tool-notifications')
            participantsContainer: @_$container.find('.js-team-members')[0]
        @_contactPicker = new AccountSetupContactPicker(contactPickerContainer, @_waveProcessor, params)
        @_contactPicker.updateContacts()
        @_contactPicker.setParticipants(@_participants) if @_participants.length > 0

    destroy: ->
        @_$container.empty()
        delete @_$container
        delete @_contactPicker
        delete @_participants
        delete @_teamType
        delete @_waveProcessor
        delete @_accountSetupWizard
        delete @_accountSetupProcessor

class BusinessCreateTeam
    constructor: (@_$container) ->
        @_waveProcessor = require('../wave/processor').instance

    renderAndInit: ->
        @_$container.empty()
        @_$container.append(renderBusinessCreateTeam())
        @_$container.find('input').placeholder?()
        @_submitButton = @_$container.find('.js-submit-button button')
        @_init()

    _init: ->
        @_initContactPicker()
        window.setTimeout =>
            @_$container.find('.js-team-name').focus()
        , 0
        @_submitButton.on 'click', =>
            @_$container.find('.js-error-text').hide()
            emails = @_contactPicker.getEmails()
            teamName = @_$container.find('.js-team-name').val()
            if teamName.length == 0
                $errText = @_$container.find('.js-error-text')
                $errText.show()
                $errText.animate({opacity: 1}, 500, ->
                    $errText.animate({opacity: 0.4}, 500)
                )
                return
            @_submitButton.off()
            @_submitButton.text('Creating...')
            @emit('create-team', emails, teamName)

    _initContactPicker: ->
        contactPickerContainer = @_$container.find('.js-account-wizard-contact-picker-container')[0]
        params =
            participantsStringLength: 1
            notificationContainer: @_$container.find('.js-invite-tool-notifications')
            participantsContainer: @_$container.find('.js-team-members')[0]
        @_contactPicker = new AccountSetupContactPicker(contactPickerContainer, @_waveProcessor, params)
        @_contactPicker.updateContacts()

    destroy: ->
        @_$container.empty()
        delete @_$container
        delete @_contactPicker
        delete @_waveProcessor
MicroEvent.mixin(BusinessCreateTeam)

class EditTeam
    constructor: (@_$container, @_topicId, @_teamName, @_participants) ->
        @_waveProcessor = require('../wave/processor').instance

    renderAndInit: ->
        @_$container.empty()
        @_$container.append(renderEditTeam())
        @_$container.find('input').placeholder?()
        @_$container.find('.js-team-name').val(@_teamName)
        @_initContactPicker()

    _initContactPicker: ->
        contactPickerContainer = @_$container.find('.js-account-wizard-contact-picker-container')[0]
        params =
            participantsStringLength: 1
            notificationContainer: @_$container.find('.js-invite-tool-notifications')
            participantsContainer: @_$container.find('.js-team-members')[0]
        @_contactPicker = new AccountSetupContactPicker(contactPickerContainer, @_waveProcessor, params)
        @_contactPicker.updateContacts()
        @_contactPicker.setParticipants(@_participants)
        @_contactPicker.on 'add-participant', (email) => @emit('add-participant', email)
        @_contactPicker.on 'remove-participant', (email) => @emit('remove-participant', email)

    destroy: ->
        @_$container.empty()
        delete @_$container
        delete @_contactPicker
        delete @_participants
        delete @_waveProcessor
MicroEvent.mixin(EditTeam)

class AccountSetupContactPicker extends ContactPicker
    __createDOM: ->
        super()
        @_$emailError = $('<span class="error-text">Invalid email</span>')
        @_$emailError.hide()
        $(@_container).find('.js-contact-picker-email').before(@_$emailError)

    __renderParticipants: (action) ->
        ###
        Обновляет список участников
        @param action: string, действие, после которого происходит обновление
        ###
        res = ''
        for p in @_participants
            res += renderTeamMember({p: p.toObject()})
        @_$participantsContainer.html(res)
        # Скроллируем список участников в самый низ
        @_$participantsContainer.scrollTop(1000000) if action is 'add'
        $(@_$participantsContainer).find('.js-remove-item').on 'click', (e) =>
            @_removeParticipant($(e.target).parent().find('.js-email').text())

    __showWarning: ->
        ###
        Сообщение может быть только о том, что e-mail неверен
        ###
        @_$emailError.css('display', 'block')
        @_$emailError.animate {opacity: 1}, 500, =>
            @_$emailError.animate({opacity: 0.4}, 500)

MicroEvent.mixin(CreateTeam)
module.exports = {CreateTeam, EditTeam, BusinessCreateTeam, BUSINESS_PANEL_TYPE, FREE_PANEL_TYPE}