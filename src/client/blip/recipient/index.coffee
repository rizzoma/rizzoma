{renderRecipient, renderRecipientInput, renderRecipientPopup} = require('./template')
{UserPicker} = require('../user_picker')
{strip} = require('../../utils/string')
{setUserPopupBehaviour} = require('../../popup/user_popup')
{popup, PopupContent} = require('../../popup')
{KeyCodes} = require('../utils/key_codes')
KeyEventNames = require('../utils/browser_events').KEY_EVENTS.join(' ')


class RecipientPopup extends PopupContent
    constructor: (user, @_canDelete, @_canConvert, @_removeCallback, @_convertCallback) ->
        @_render(user)

    _render: (user) ->
        @_container = document.createElement('span')
        $container = $(@_container)
        params =
            avatar: user.getAvatar()
            initials: user.getInitials()
            name: user.getName()
            email: user.getEmail()
            canDelete: @_canDelete(user.getId())
            canConvert: @_canConvert(user.getId())
            showConvertButton: require('../../account_setup_wizard/processor').instance.isBusinessUser()
        $container.append(renderRecipientPopup(params))
        $container.find('.js-remove-recipient').on 'click', =>
            @_removeCallback()
            popup.hide()
        $container.find('.js-convert-to-task').on 'click', =>
            @_convertCallback()
            popup.hide()

    getContainer: ->
        @_render() if not @_container
        return @_container

    destroy: ->
        delete @_container
        delete @_removeCallback
        delete @_convertCallback


class RecipientInput
    constructor: (@_waveViewModel) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        c = $(@_container)
        c.append(renderRecipientInput())
        @_input = c.find('.js-recipient-input')[0]
        @_userPicker = new UserPicker(@_waveViewModel)
        @_userPicker.activate(@_input)
        @_userPicker.on('select-contact', @_contactSelectHandler)
        @_userPicker.on('select-email', @_emailSelectHandler)
        @_userPicker.on('finish', @_cancelRecipientInput)
        $(@_container).on(KeyEventNames, @_checkEscKey)
        @_state = 'input'

    _contactSelectHandler: (contact) =>
        return @_insertRecipientById(contact.id) if contact.id
        @_insertRecipientByEmail(strip(contact.email))

    _emailSelectHandler: (email) =>
        @_insertRecipientByEmail(strip(email))

    _trackRecipientInsertion: ->
        _gaq.push(['_trackEvent', 'Mention', 'Mention creation', @insertionEventLabel || 'Hotkey'])
        mixpanel.track('Create mention')

    _trackRecipientCancel: ->
        _gaq.push(['_trackEvent', 'Mention', 'Mention cancellation'])

    _insertRecipientById: (id) ->
        @_state = 'inserted'
        $(@_container).trigger('itemSelected', id)
        @_trackRecipientInsertion()

    _cancelRecipientInput: =>
        $(@_container).trigger('cancel', @getValue())

    _checkEscKey: (event) =>
        return if event.keyCode? and event.keyCode isnt KeyCodes.KEY_ESCAPE
        @_cancelRecipientInput()

    _insertRecipientByEmail: (email) ->
        return if @_state isnt 'input'
        insert = =>
            $(@_container).trigger('emailSelected', email)
            @_trackRecipientInsertion()
            @_state = 'inserted'
        return insert() if not @_waveViewModel.haveEmails()
        user = @_waveViewModel.getParticipantByEmail(email)
        return @_insertRecipientById(user.getId()) if user
        if not @_userPicker.isValid(email)
            @_state = 'input'
            return @_waveViewModel.showWarning('Enter valid e-mail')
        # В firefox код после window.confirm выполняется асинхронно, поэтому отмена вставки по blur может произойти
        # раньше, чем мы узнаем результат confirm'а. Выключим обработку остальных событий, все равно наши дальнейшие
        # действия зависят только от результата confirm'а
        $(@_container).off(KeyEventNames, @_checkEscKey)
        @_userPicker.removeListener('finish', @_cancelRecipientInput)
        # confirm может поломать порядок выполнения событий, из-за чего вызывается два _insertRecipientByEmail
        @_state = 'confirming'
        if window.confirm("This user is not participant of the topic. Add #{email} to the topic?")
            insert()
        else
            $(@_container).trigger('cancel')
            @_trackRecipientCancel()
            @_state = 'canceled'

    getContainer: ->
        @_container

    getValue: ->
        $(@_input).val()

    stub: (email) ->
        stubbedRecipient = new RecipientStub(email)
        $(@_container).replaceWith(stubbedRecipient.getContainer())
        return stubbedRecipient

    focus: ->
        @_input.focus()

    destroy: ->
        delete @_waveViewModel
        @_userPicker?.destroy()
        delete @_userPicker
        $(@_container).remove()


class RecipientStub
    constructor: (email) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        $(@_container).append(renderRecipient({name: email}))

    destroy: ->
        $(@_container).remove()

    getContainer: ->
        @_container


class Recipient
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_canDelete, @_canConvert, @_id, @_removeCallback, @_convertCallback) ->
        @_createDom()
        @_waveViewModel.on('usersInfoUpdate', @_updateUserInfo)

    _updateUserInfo: (userIds) =>
        for userId in userIds
            return @render() if @_id is userId

    _createDom: ->
        @_container ||= document.createElement 'span'
        @_container.contentEditable = 'false'
        $(@_container).empty()
        @_renderRecipient()

    _remove: =>
        _gaq.push(['_trackEvent', 'Mention', 'Remove mention with popup'])
        @_removeCallback?(@)

    _convert: =>
        _gaq.push(['_trackEvent', 'Mention', 'Convert to Task'])
        recipient = @_convertCallback(@)
        window.setTimeout ->
            recipient.showPopup()
        , 0

    _renderRecipient: () ->
        $c = $(@_container)
        user = @_waveViewModel.getUser(@_id)
        $c.append(renderRecipient({name: user.getName()}))
        setUserPopupBehaviour($c, RecipientPopup, user, @_canDelete, @_canConvert, @_remove, @_convert)

    render: ->
        @_createDom()

    getContainer: ->
        @_container

    getId: ->
        @_id

    markAsInvalid: (message) ->
        $(@_container).children().css('border', '1px inset red').attr('title', message)

    destroy: ->
        @_waveViewModel.removeListener('usersInfoUpdate', @_updateUserInfo)
        delete @_waveViewModel
        delete @_removeCallback
        delete @_convertCallback


exports.Recipient = Recipient
exports.RecipientInput = RecipientInput
