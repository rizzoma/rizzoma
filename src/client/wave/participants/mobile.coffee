{ROLES, ROLE_OWNER, ROLE_EDITOR, ROLE_NO_ROLE} = require('./constants')

class Participants
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_processor, @_modelId, @_participants, @_allowRemove, @_changeCallback) ->
        @_waveViewModel.getUsers(@_getParticipantsIds())

    _getParticipantsIds: (checkRole = no) ->
        participantIds = []
        for participant in @_participants
            continue if checkRole and participant.role == ROLE_NO_ROLE
            participantIds.push(participant.id)
        participantIds

    _add: (participant, index) ->
        @_participants[index...index] = [participant]

    _remove: (participant, index) ->
        @_participants[index..index] = []

    all: ->
        ###
        Возвращает массив идентификаторов текущих участников волны
        ###
        @_getParticipantsIds(yes)

    applyOp: (op) ->
        index = op.p.shift()
        if op.ld
            @_remove op.ld, index
        if op.li
            @_add op.li, index
        @_changeCallback?()

    destroy: ->
        delete @_waveViewModel
        delete @_processor
        delete @_modelId
        delete @_participants
        delete @_allowRemove
        delete @_changeCallback if @_changeCallback

exports.Participants = Participants
