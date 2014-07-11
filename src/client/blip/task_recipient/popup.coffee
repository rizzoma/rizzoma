{popup, PopupContent} = require('../../popup')
{UserPicker} = require('../user_picker')
{convertDateTimeToClient, convertDateTimeToServer} = require('../../../share/utils/date_converter')
{strip} = require('../../utils/string')
{DateTimePicker} = require('../../utils/date_time_picker')
{NOT_PERFORMED_TASK, PERFORMED_TASK} = require('../../search_panel/task/constants')
ck = window.CoffeeKup


renderTaskRecipientPopup = ck.compile ->
    div '.task-recipient-popup', ->
        div '.task-recipient-info', ->
            div '.js-task-recipient-icon.task-recipient-avatar.avatar', {style: "background-image: url(#{h(@user.getAvatar())})"}, h(@user.getInitials())
            div '.task-recipient-input-container', ->
                params =
                    type: 'text'
                    tabindex: '1'
                    value: @user.getEmail() || @user.getName()
                params.disabled = 'disabled' if not @canChangeRecipient
                input '.js-task-recipient-input.task-recipient-input', params
        div '.task-date-container', ->
            date = @deadline.date || ''
            time = @deadline.time || ''
            dateParams = {type: 'text', tabindex: '2', value: date}
            timeParams = {type: 'text', tabindex: '3', value: time}
            if not @canChangeFields
                dateParams.disabled = timeParams.disabled = 'disabled'
            div '.date-icon.js-date-icon', ''
            input '.js-task-date-input.task-date-input', dateParams
            div '.time-icon.js-time-icon', ''
            input '.js-task-time-input.task-time-input', timeParams
        div '.task-is-completed-container', ->
            completeParams = {type: 'checkbox', id: 'task-popup-is-complete'}
            completeParams.checked = 'checked' if @completed
            completeParams.disabled = 'disabled' if not @canChangeFields
            input '.js-task-complete.custom', completeParams
            label '.task-recipient-complete', {for: 'task-popup-is-complete'}, 'Complete'
        div '.task-bottom-container', ->
            deleteParams = {}
            deleteParams.disabled = 'disabled' if not @canDelete
            button '.js-remove-task-recipient.remove-task-recipient', deleteParams, 'Delete'
            convertParams = {}
            convertParams.disabled = 'disabled' if not @canConvert
            button '.js-convert-to-mention', convertParams, 'Convert to @'
            button '.js-close.close-popup', 'Close'


class TaskRecipientPopup extends PopupContent
    constructor: (taskData, @_waveViewModel, @_canChangeRecipient, @_canChangeFields, @_canDelete, @_canConvert, @_updateCallback, @_remove, @_convertCallback) ->
        @_userPicker = new UserPicker(@_waveViewModel)
        @_dateTimePicker = new DateTimePicker()
        @_render(taskData)

    _render: (taskData) ->
        @_container = document.createElement('span')
        user = @_waveViewModel.getUser(taskData.recipientId)
        templateData =
            user: user
            completed: taskData.status is PERFORMED_TASK
            canChangeRecipient: @_canChangeRecipient()
            canChangeFields: @_canChangeFields()
            canDelete: @_canDelete()
            canConvert: @_canConvert()
        [date, time] = convertDateTimeToClient(taskData.deadlineDate, taskData.deadlineDatetime)
        templateData.deadline = {date, time}
        $container = $(@_container)
        $container.append(renderTaskRecipientPopup(templateData))
        @_initRecipientInput()
        @_initDateTimeInputs()
        @_taskIsCompleteInput = $container.find('.js-task-complete')[0]
        $(@_taskIsCompleteInput).click(@_save)
        $(@_container).find('.js-convert-to-mention').click(@_convert)
        $(@_container).find('.js-remove-task-recipient').click(@_removeTaskRecipient)
        $(@_container).find('.js-close').click ->
            popup.hide()

    _initRecipientInput: ->
        $container = $(@_container)
        @_recipientInput =  $container.find('.js-task-recipient-input')[0]
        @_userPicker.activate(@_recipientInput)
        @_userPicker.on 'select-contact', (contact) => @_processEmailChange(contact.email)
        @_userPicker.on 'select-email', @_processEmailChange

    _processEmailChange: (email) =>
        return if not @_validateRecipientEmail(email)
        $(@_recipientInput).val(email).blur()
        return if not @_save()
        participant = @_waveViewModel.getParticipantByEmail(email)
        $(@_container).find('.js-task-recipient-icon').css("background-image", "url(#{participant.getAvatar()})")
        $(@_container).find('.js-task-recipient-icon').text(participant.getInitials())

    _validateRecipientEmail: (email) ->
        return true if @_userPicker.isValid(email)
        @_waveViewModel.showWarning('Enter valid e-mail')
        return false

    _initDateTimeInputs: ->
        return if not @_canChangeFields()
        $container = $(@_container)
        dateInput = $container.find('.js-task-date-input')[0]
        timeInput = $container.find('.js-task-time-input')[0]
        @_dateTimePicker.init(dateInput, timeInput)
        $container.find('.js-date-icon').click => $(dateInput).focus()
        $container.find('.js-time-icon').click => $(timeInput).focus()
        @_dateTimePicker.on 'change', (date, time) =>
            @_save() if @_validateDateTime(date, time)

    _validateDateTime: (date, time) =>
        [dateIsValid, timeIsValid] = @_dateTimePicker.validate(date, time)
        if not dateIsValid
            @_waveViewModel.showWarning('Enter valid date (day.month.year)')
            return false
        # Не показываем обе ошибки сразу, т.к. валидация времени зависит от даты
        if not timeIsValid
            @_waveViewModel.showWarning('Enter valid time (hours:minutes)')
            return false
        return true

    _update: (data) ->
        ###
        Обновляет поля в task'е. Если сам объект задачи изменился, получает из него функции обновления и удаления.
        @return: boolean, можно ли оставить popup открытым после
        ###
        newTask = @_updateCallback(data)
        return false if not newTask?
        @_updateCallback = newTask.update
        @_remove = newTask.remove
        @_convertCallback = newTask.convert
        return true

    _convert: =>
        @_convertCallback()
        popup.hide()

    _save: =>
        email = strip($(@_recipientInput).val())
        [date, time] = @_dateTimePicker.get()
        status = if @_taskIsCompleteInput.checked then PERFORMED_TASK else NOT_PERFORMED_TASK
        return false if not @_validateAll(email, date, time)
        participant = @_waveViewModel.getParticipantByEmail(email)
        if !participant
            return false if !window.confirm("This user is not participant of the topic. Add #{email} to the topic?")
        newTaskData = {status}
        if participant
            newTaskData.recipientId = participant.getId()
        else
            newTaskData.recipientEmail = email
        [date, datetime] = convertDateTimeToServer(date, time)
        newTaskData.deadlineDate = date
        newTaskData.deadlineDatetime = datetime
        if not @_update(newTaskData)
            # Нода с задачей удалена при перерендеринге, нужно закрыть popup
            popup.hide()
            return false
        return true

    _validateAll: (email, date, time) ->
        return false if not @_validateRecipientEmail(email)
        return false if not @_validateDateTime(date, time)
        return true

    _removeTaskRecipient: =>
        @_remove()
        popup.hide()

    destroy: ->
        @_userPicker?.destroy()
        delete @_userPicker
        @_dateTimePicker?.destroy()
        delete @_dateTimePicker
        $(@_container).remove()
        delete @_container
        delete @_remove
        delete @_updateCallback
        delete @_convertCallback

    getContainer: ->
        @_render() if not @_container
        return @_container

    shouldCloseWhenClicked: (e) ->
        autocomplete = @_userPicker.getAutocompleteContainer()
        return true if not autocomplete?
        !$.contains(autocomplete, e)

module.exports = {TaskRecipientPopup}