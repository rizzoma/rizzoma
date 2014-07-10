{UserPicker} = require('../user_picker')
{DateTimePicker} = require('../../utils/date_time_picker')
{strip} = require('../../utils/string')
MicroEvent = require('../../utils/microevent')
BrowserEvents = require('../../utils/browser_events')
{KeyCodes} = require('../../utils/key_codes')
{TaskRecipientStub} = require('./index')
{convertDateTimeToServer, formatAsClientDate} = require('../../../share/utils/date_converter')
{NOT_PERFORMED_TASK} = require('../../search_panel/task/constants')
ck = window.CoffeeKup

renderRecipientInput = ck.compile ->
    span '.task-recipient-creation-form.js-task-recipient-creation-form', ->
        input {type: 'checkbox', disabled: 'disabled'}
        input '.js-task-recipient-input .task-recipient-input', {type: "text", tabindex: "0"}
        input '.js-task-recipient-deadline-input', {type: "text", tabindex: "0", style: 'display: none'}

renderTaskRecipientName = ck.compile ->
    span '.task-recipient-text', h(@name)


class TaskRecipientInput
    constructor: (@_waveViewModel, @_updateTaskSearchInfo) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        c = $(@_container)
        c.append(renderRecipientInput())
        @_state = 'start'
        @_taskData = {status: NOT_PERFORMED_TASK, senderId: window.userInfo.id}
        @_activateRecipientInput()

    _activateRecipientInput: ->
        @_recipientInput =$(@_container).find('.js-task-recipient-input')[0]
        @_userPicker = new UserPicker(@_waveViewModel)
        @_userPicker.activate(@_recipientInput)
        @_userPicker.on 'select-contact', (contact) =>
            return @_selectRecipientById(contact.id) if contact.id
            @_selectRecipientByEmail(contact.email)
        @_userPicker.on 'select-email', (email) =>
            @_selectRecipientByEmail(strip(email))
        @_userPicker.on 'finish', =>
            @_cancelTask(@getValue()) if @_state is 'recipient-input'
        @_state = 'recipient-input'

    _cancelInput: (state, callback, reason) ->
        window.setTimeout =>
            return if @_state isnt state
            callback(reason)
        , 200

    _bindCancel: (item, state, skipClass, callback) ->
        $(item).bind BrowserEvents.KEY_EVENTS.join(' '), (event) =>
            return if event.keyCode isnt KeyCodes.KEY_ESCAPE and
                event.keyCode isnt KeyCodes.KEY_TAB
            @_cancelInput(state, callback, 'key')
        @_bodyClickCallback = (e) =>
            return if not e.target
            curElement = e.target
            while curElement
                return if $(curElement).is(skipClass)
                curElement = curElement.parentNode
            @_cancelInput(state, callback, 'blur')
            $('body').off('click', @_bodyClickCallback)
        $('body').on('click', @_bodyClickCallback)

    _cancelTask: (text) ->
        @emit('cancel', text)

    _replaceRecipientInput: (name) ->
        @_userPicker?.destroy()
        recipientName = renderTaskRecipientName({name})
        $(@_recipientInput).replaceWith(recipientName)

    _trackRecipientInsertion: ->
        _gaq.push(['_trackEvent', 'Task', 'Task creation', @insertionEventLabel || 'Hotkey'])

    _trackRecipientCancel: ->
        _gaq.push(['_trackEvent', 'Task', 'Task cancellation'])

    _selectRecipientById: (id) ->
        return if @_selecting
        @_selecting = true
        @_taskData.recipientId = id
        name = @_waveViewModel.getUser(@_taskData.recipientId).getName()
        @_replaceRecipientInput(name)
        @_activateDeadlineInput()
        @_selecting = false

    _selectRecipientByEmail: (email) ->
        # confirm может поломать порядок выполнения событий, из-за чего вызывается два _selectRecipientBy
        return if @_selecting
        @_selecting = true
        insert = =>
            @_selectEmail(email)
        if @_waveViewModel.haveEmails()
            user = @_waveViewModel.getParticipantByEmail(email)
            if user
                @_selectEmail(email)
            else
                if @_userPicker.isValid(email)
                    if window.confirm("This user is not participant of the topic. Add #{email} to the topic?")
                        insert()
                    else
                        @_trackRecipientCancel()
                        @_cancelTask()
                else
                    @_waveViewModel.showWarning('Enter valid e-mail')
        else
            insert()
        @_selecting = false

    _selectEmail: (email) ->
        @_taskData.recipientEmail = email
        @_replaceRecipientInput(email)
        @_activateDeadlineInput()

    _activateDeadlineInput: ->
        @_state = 'deadline-input'
        @_deadlineInput = $(@_container).find('.js-task-recipient-deadline-input')[0]
        @_bindCancel @_deadlineInput, 'deadline-input', '.js-task-recipient-creation-form, .calendricalDatePopup, .acResults', =>
            @_selectDeadline(null)
        # Создаем поле вводы даты с задержкой, иначе в firefox во вновь созданном поле возникает событие keypress
        window.setTimeout =>
            @_dateTimePicker = new DateTimePicker()
            @_dateTimePicker.initUniversalInput(@_deadlineInput, true)
            $(@_deadlineInput).show()
            $(@_deadlineInput).val(formatAsClientDate(new Date()))
            $(@_deadlineInput).select()
            $(@_deadlineInput).focus()
            @_dateTimePicker.on('universal-change', @_processDeadline)
        , 0

    _processDeadline: (hasError, date, time) =>
        if hasError
            @_waveViewModel.showWarning('Enter valid date')
            return
        [date, datetime] = convertDateTimeToServer(date, time)
        @_selectDeadline(date, datetime)

    _selectDeadline: (date, datetime) ->
        return if @_state isnt 'deadline-input'
        @_state = 'finish'
        @_taskData.deadlineDate = date
        @_taskData.deadlineDatetime = datetime
        @_trackRecipientInsertion()
        @_updateTaskSearchInfo(@_taskData)
        @emit('finish', @_taskData)

    stub: ->
        stub = new TaskRecipientStub(@_taskData.recipientEmail, @_taskData.deadlineDate, @_taskData.deadlineDatetime)
        $(@_container).replaceWith(stub.getContainer())
        return stub

    getContainer: ->
        @_container

    getValue: ->
        $(@_recipientInput).val()

    focus: ->
        @_recipientInput.focus()

    destroy: ->
        delete @_waveViewModel
        @_userPicker?.destroy()
        delete @_userPicker
        @_dateTimePicker?.destroy()
        delete @_dateTimePicker
        $(@_container).remove()
        @removeListeners('cancel')
        @removeListeners('finish')
        $('body').off('click', @_bodyClickCallback)


MicroEvent.mixin(TaskRecipientInput)
module.exports = {TaskRecipientInput}