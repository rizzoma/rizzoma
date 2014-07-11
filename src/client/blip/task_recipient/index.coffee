{setUserPopupBehaviour} = require('../../popup/user_popup')
{popup} = require('../../popup')
{TaskRecipientPopup} = require('./popup')
{formatAsShortenedDate, formatAsShortenedDateTime} = require('../../../share/utils/datetime')
{convertDate, convertDatetime, convertDateTimeToClient} = require('../../../share/utils/date_converter')
{NOT_PERFORMED_TASK, PERFORMED_TASK} = require('../../search_panel/task/constants')
ck = window.CoffeeKup

recipientTmpl = ->
    # split is added to prevent autocorrect
    span 'task-recipient-container', ->
        span 'editor-el-split', '|'
        span 'task-recipient', ->
            id = 'task-recipient-completed' + Math.random()
            inputParams = {type: 'checkbox', id}
            inputParams.disabled = 'disabled' if @isStub
            inputParams.checked = 'checked' if @isCompleted
            input 'js-task-completed custom', inputParams
            label {for: id}, ''
            span 'js-recipient-task-info', ->
                span 'task-recipient-text', h(@name)
                span('task-recipient-deadline', h(@deadline)) if @deadline
        span 'editor-el-split', '|'

renderRecipientTmpl = ck.compile(recipientTmpl)

renderRecipient = (name, deadlineDate, deadlineDatetime, status, isStub) ->
    params =
        name: name
        isCompleted: status is PERFORMED_TASK
        isStub: isStub
    params.deadline = formatAsShortenedDate(convertDate(deadlineDate)) if deadlineDate?
    params.deadline = formatAsShortenedDateTime(convertDatetime(deadlineDatetime)) if deadlineDatetime?
    renderRecipientTmpl(params)


class TaskRecipient
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_data, @_updateCallback, @_removeCallback, @_convertCallback, @_updateTaskSearchInfo, @_canEditBlip) ->
        @_render()
        @_waveViewModel.on('usersInfoUpdate', @_updateUserInfo)
        @_initCompleted()

    _canChangeRecipient: => @_canEditBlip() and @_waveViewModel.haveEmails()

    _canChangeFields: =>
        @_canEditBlip() or
            @_data.recipientId is window.userInfo?.id

    _canDelete: =>
        @_canEditBlip() or
            @_data.recipientId is window.userInfo?.id

    _canConvert: => @_canEditBlip()

    _updateUserInfo: (userIds) =>
        for userId in userIds when @_data.recipientId is userId
            return @_render()

    _render: ->
        @_container ||= document.createElement 'span'
        @_container.contentEditable = 'false'
        $c = $(@_container)
        $c.empty()
        user = @_waveViewModel.getUser(@_data.recipientId)
        $c.append(renderRecipient(user.getName(), @_data.deadlineDate, @_data.deadlineDatetime, @_data.status))
        popupArea = $c.find('.js-recipient-task-info')
        setUserPopupBehaviour(popupArea, TaskRecipientPopup, @_data, @_waveViewModel, @_canChangeRecipient, @_canChangeFields, @_canDelete, @_canConvert, @update, @remove, @convert)

    _initCompleted: ->
        $(@_container).click '.js-task-completed', =>
            return false if not @_canChangeFields()
            completedCheckbox = $(@_container).find('.js-task-completed')[0]
            data = {status: if completedCheckbox.checked then PERFORMED_TASK else NOT_PERFORMED_TASK}
            for p in ['recipientId', 'deadlineDate', 'deadlineDatetime']
                data[p] = @_data[p]
            _gaq.push(['_trackEvent', 'Task', 'Task state changed from text', @_getStatusLabel(data.status)])
            @_update(data)

    _getStatusLabel: (status) ->
        if status is PERFORMED_TASK then 'complete' else 'uncomplete'

    remove: =>
        _gaq.push(['_trackEvent', 'Task', 'Remove task with popup'])
        @_removeCallback?()

    update: (data) =>
        changedFields = []
        [orgDate, orgTime] = convertDateTimeToClient(@_data.deadlineDate, @_data.deadlineDatetime)
        [date, time] = convertDateTimeToClient(data.deadlineDate, data.deadlineDatetime)
        changedFields.push('date') if orgDate isnt date
        changedFields.push('time') if orgTime isnt time
        changedFields.push('recipient') if @_data.recipientId isnt data.recipientId
        changedFields.push(@_getStatusLabel(data.status)) if @_data.status isnt data.status
        _gaq.push(['_trackEvent', 'Task', 'Task changed', changedFields.join(',')])
        return @_update(data)

    convert: =>
        _gaq.push(['_trackEvent', 'Task', 'Convert to Mention'])
        @_convertCallback()

    _update: (data) ->
        data.senderId = @_data.senderId
        @_updateTaskSearchInfo(data)
        return @_updateCallback(data)

    getRecipientId: -> @_data.recipientId

    markAsInvalid: (message) ->
        $(@_container).children().css('border', '1px inset red').attr('title', message)

    markAsValid: (message) ->
        $(@_container).children().css('border', 'none')

    getContainer: ->
        @_container

    destroy: ->
        @_waveViewModel?.removeListener('usersInfoUpdate', @_updateUserInfo)
        delete @_waveViewModel

    getData: -> @_data

    showPopup: ->
        popup.hide()
        popup.render(new TaskRecipientPopup(@_data, @_waveViewModel, @_canChangeRecipient, @_canChangeFields, @_canDelete, @_canConvert, @update, @remove, @convert), @_container)
        popup.show()


class TaskRecipientStub
    constructor: (name, date, datetime) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        $container = $(@_container)
        deadline = convertDateTimeToClient(date, datetime)[0]
        $container.append(renderRecipient(name, date, datetime, NOT_PERFORMED_TASK, true))

    destroy: ->
        $(@_container).remove()

    getContainer: ->
        @_container

module.exports = {TaskRecipient, TaskRecipientStub}
