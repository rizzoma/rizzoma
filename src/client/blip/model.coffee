ModelField = require('../editor/model').ModelField
ParamsField = require('../editor/model').ParamsField
ModelType = require('../editor/model').ModelType

EDIT_PERMISSION = 'edit'
COMMENT_PERMISSION = 'comment'
READ_PERMISSION = 'read'

class BlipModel

    constructor: (args...) ->
        @_init args...

    _init: (@_doc, waveId, @isRead, @title) ->
        ###
        @param title: заголовок блипа сервер передает только для корневого блипа
        ###
        @id = @_doc.name # TODO: deprecated
        @serverId = @_doc.serverId
        @waveId = waveId
        @_childBlips = {}

    submitOps: (ops) ->
        ###
        Отправляет операции пользователя на сервер
        @param ops: [ShareJS operation]
        ###
        @_doc.submitOp(ops)

    isFoldedByDefault: ->
        ###
        Возвращает true, если блип нужно по умолчанию показывать свернутым
        @return: boolean
        ###
        @_doc.snapshot.isFoldedByDefault

    setIsFoldedByDefault: (value) ->
        ###
        Устанавливает значение флага isFoldedByDefault
        @param value: boolean
        ###
        return if value is @isFoldedByDefault()
        op =
            p: ['isFoldedByDefault']
            od: @isFoldedByDefault()
            oi: value
        @_doc.submitOp([op])

    getVersion: () ->
        @_doc.version

    getSnapshotContent: () ->
        @_doc.snapshot.content

    getContributors: ->
        @_doc.snapshot.contributors

    getChildBlipsPositions: ->
        ###
        Возвращает позиции дочерних блипов
        @return: object {blipId: pos}
        ###
        pos = 0
        res = {}
        for block in @getSnapshotContent()
            if block[ModelField.PARAMS][ParamsField.TYPE] is ModelType.BLIP
                id = block[ModelField.PARAMS][ParamsField.ID]
                res[id] = pos
            pos += block[ModelField.TEXT].length
        return res

    onChange: (callback) ->
        ###
        ###
        @_doc.on('change', callback)

    getMessageInfo: ->
        @_doc.snapshot.pluginData?.message

    getServerId: -> @_doc.serverId

    getId: ->
        @_doc.name

    _getBlockText: (block) ->
        switch block[ModelField.PARAMS][ParamsField.TYPE]
            when ModelType.TEXT then block[ModelField.TEXT]
            when ModelType.TAG then '#' + block[ModelField.PARAMS][ParamsField.TAG]
            when ModelType.LINE then ' '
            else ''

    _getLinesText: (from, to) ->
        lineNumber = -1
        res = ''
        for block in @_doc.snapshot.content
            if block[ModelField.PARAMS][ParamsField.TYPE] is ModelType.LINE
                lineNumber++
            break if lineNumber > to
            if lineNumber >= from
                res += @_getBlockText(block)
        return res

    getTitle: ->
        @_getLinesText(0, 0)

    getSnippet: ->
        @_getLinesText(1)[0..100]

    getAuthorId: ->
        @_doc.snapshot.contributors[0].id

    getChildBlips: -> @_childBlips

    destroy: ->
        delete @_childBlips

module.exports = {BlipModel, EDIT_PERMISSION, COMMENT_PERMISSION, READ_PERMISSION}
