_ = require('underscore')
async = require('async')
Model = require('../common/model').Model
DateUtils = require('../utils/date_utils').DateUtils
IdUtils = require('../utils/id_utils').IdUtils
HashUtils = require('../utils/hash_utils').HashUtls
Conf = require('../conf').Conf
WavePermissionsChecker = require('./permissions').WavePermissionsChecker
TeamModel = require('../team/model').TeamModel

Ptag = require('../ptag').Ptag
ALL_PTAG_ID = Ptag.ALL_PTAG_ID
FOLLOW_PTAG_ID = Ptag.FOLLOW_PTAG_ID
UNFOLLOW_PTAG_ID = Ptag.UNFOLLOW_PTAG_ID

SHARED_STATES = require('./constants').SHARED_STATES
DENIAL_REASONS = require('./constants').DENIAL_REASONS
ROLES = require('./constants').ROLES
BLOCKING_STATES = require('./constants').BLOCKING_STATES
ACTIONS = require('./constants').ACTIONS
TOPIC_TYPES = require('./constants').TOPIC_TYPES

WaveError = require('./exceptions').WaveError
WAVE_PARTICIPANT_ALREADY_IN = require('./exceptions').WAVE_PARTICIPANT_ALREADY_IN
WAVE_PARTICIPANT_NOT_IN = require('./exceptions').WAVE_PARTICIPANT_NOT_IN
WAVE_NO_ANOTHER_MODERATOR = require('./exceptions').WAVE_NO_ANOTHER_MODERATOR
WAVE_INVALID_PARAM_VALUE = require('./exceptions').WAVE_INVALID_PARAM_VALUE

SuperUserModel = require('../user/model').SuperUserModel

URL_LENGTH = 16

REFERAL_EMAIL_SALT = Conf.getReferalEmailSalt()

class ParticipantModel
    constructor: (@id=null, @role=ROLES.ROLE_NO_ROLE, @ptags=[], @blockingState=BLOCKING_STATES.NON_BLOCKED, @actionLog=[]) ->

    hasRole: () ->
        role = @role
        return role and role != ROLES.ROLE_NO_ROLE

    isBlocked: () ->
        @blockingState == BLOCKING_STATES.BLOCKED

    getReferalEmailHash: (waveId) ->
        ###
        Возвращает хэш пользователя (для авторизации при переходи с email)
        ###
        return HashUtils.getSHA1Hash("#{waveId}#{@id}#{REFERAL_EMAIL_SALT}")

    isTopicCreator: () ->
        return @role == ROLES.ROLE_TOPIC_CREATOR

    addAction: (user, action) ->
        id = if user then user.id else 'server'
        @actionLog.push({userId: id, action, date: DateUtils.getCurrentTimestamp()})

    flushActions: () ->
        @actionLog = []

    toObject: () ->
        return {id: @id, role: @role, ptags: @ptags, blockingState: @blockingState, actionLog: @actionLog}

class WaveModel extends Model
    ###
    Класс, представляющий базовую модель волны.
    ###
    constructor: (@id=null, @_rev=undefined, @participants=[], @rootBlipId=null, @contentTimestamp=DateUtils.getCurrentTimestamp(), @version=0, @sharedState=SHARED_STATES.SHARED_STATE_PRIVATE, @urls=[], @sharedToSocial=false, @sharedToSocialTime=0, @defaultRole=ROLES.ROLE_EDITOR, @topicType=TOPIC_TYPES.TOPIC_TYPE_ORDINARY, @_options={}, @_balance={}, @gDriveId=null, @gDrivePermissions=null) ->
        @updateUrls()
        super('wave')
        @_permissionsChecker = new WavePermissionsChecker(@)
        @team = new TeamModel(@)

    _participantsMap: (iterator) ->
        items = []
        for participant, index in @participants
            item = iterator(participant, index)
            items.push(item) if item
        return items

    _getParticipant: (user, role=false, blocking=false) ->
        iterator = (participant, index) ->
            return if role and not participant.hasRole()
            return if blocking and participant.isBlocked()
            return [participant, index] if user.isEqual(participant.id)
        participant = @_participantsMap(iterator)
        return if participant.length then participant[0] else [null, null]

    getParticipantsWithRole: (blocking=false) ->
        ###
        Возвращает действительных участников волны (с правами).
        ###
        iterator = (participant) ->
            return if not participant.hasRole()
            return if blocking and participant.isBlocked()
            return participant
        return @_participantsMap(iterator)

    getParticipant: (user, role) ->
        ###
        Возвращает участника волны
        @param id: string
        @returns: UserModel | null
        ###
        [participant, index] = @_getParticipant(user, role)
        return participant

    updateUrls: () ->
        @urls.push(IdUtils.getRandomId(URL_LENGTH))

    hasParticipant: (user, role) ->
        ###
        Проверяет, добавлен ли этот участник в волну.
        @param id: string - id участника.
        @returns: bool
        ###
        return !!@getParticipant(user, role)

    getSharedState: () ->
        ###
        Возвращает состояние публичности волны
        ###
        return @sharedState

    getDefaultRole: () ->
        ###
        Возвращает роль поумолчанию.
        @returns: int
        ###
        return @defaultRole

    checkPermission: (user, action) ->
        ###
        Проверяет возможность выполнения действия пользователем в этой волне.
        @param user: UserModel
        @param action: int
        @returns: bool
        ###
        @_permissionsChecker.autorizeAction(user, action)

    authorizeUser: (user) ->
        ###
        Возвращает роль пользователя в волне, либо причину отказа в доступе.
        @param user:UserModel
        @returns: [denialReason: int, role: int]
        Правила авторизации:
                |Anonymous|Blocked|     Logged in
        ________|_________|_______|___________________
        Private |   dra   |  drb  |       drn
        Shared  |  reader |  bpd  |role || defaultRole
        Public  |  reader |  bpd  |role || defaultRole
            dra - DENIAL_REASON_ANONYMOUS
            drb - DENIAL_REASON_BLOCKED
            drn - DENIAL_REASON_NOT_IN_TOPIC
        ###
        sharedState = @getSharedState()
        if not user
            #todo: разобраться почему происходит ошибка при обработке входящего письма, подробности https://rizzoma.com/topic/cc0cc4f17addb6ed4c6fffe75a8afcb0/0_b_7i_4sm7l/
            console.error("Bugcheck: no user in authorizeUser", user, @id)
            return [DENIAL_REASONS.DENIAL_REASON_ANONYMOUS, null]
        if user.isAnonymous()
            return [null, ROLES.ROLE_ANONYMOUS_READER] if sharedState == SHARED_STATES.SHARED_STATE_PUBLIC
            return [DENIAL_REASONS.DENIAL_REASON_ANONYMOUS, null]
        if user instanceof SuperUserModel
            return [null, ROLES.ROLE_EDITOR]
        role = ROLES.ROLE_NO_ROLE
        participant = null
        for currentParticipant in @participants when user.isEqual(currentParticipant.id)
            continue if currentParticipant.role >= role
            role = currentParticipant.role
            participant = currentParticipant
        return [DENIAL_REASONS.DENIAL_REASON_BLOCKED, null] if user.isBlocked() or participant?.isBlocked()
        if not participant and sharedState == SHARED_STATES.SHARED_STATE_PRIVATE
            return [DENIAL_REASONS.DENIAL_REASON_NOT_IN_TOPIC, null]
        role = @getDefaultRole() if role == ROLES.ROLE_NO_ROLE
        return [null, role]

    markAsChanged: (changes) ->
        super(changes, ['sharedState', 'participants'], () =>
            @_setTimestampToNow()
        )

    getUrl: () ->
        return @urls.slice(-1)[0]

    getSocialSharingUrl: ->
        url = @getUrl() + Conf.get('socialSharing').signSalt
        return HashUtils.getSHA1Hash(url)

    getParticipantIdByReferalEmailHash: (hash) ->
        ###
        Возвращает id пользователя, чей хэш совпадает с данным либо null.
        @param hash: string
        @returns: string
        ###
        iterator = (participant) =>
            return if not participant.hasRole()
            return if participant.isBlocked()
            return participant.id if hash == participant.getReferalEmailHash(@id)
        id = @_participantsMap(iterator)
        return if id.length then id[0] else null

    _getParticipantPtags: (user) ->
        ###
        Возвращает персональные тэги участника волны.
        @param id: string
        @returns: array
        ###
        return @getParticipant(user)?.ptags

    setParticipantFollowState: (user, state) ->
        ###
        Изменяет состояние подписки участника на волну
        (заменяет тэг FOLLOW на UNFOLLOW или наоборот).
        Возвращает undefined, если изменение состояния не нужно, иначе true.
        @param id: string
        @param state: bool - true - подписываемся, false - отписываемся
        @return bool
        ###
        ptags = @_getParticipantPtags(user)
        return if not ptags
        if state
            [setTagId, resetTagId] = [FOLLOW_PTAG_ID, UNFOLLOW_PTAG_ID]
        else
            [setTagId, resetTagId] = [UNFOLLOW_PTAG_ID, FOLLOW_PTAG_ID]
        return if setTagId in ptags
        index = ptags.indexOf(resetTagId)
        ptags.splice(index, 1) if index >= 0
        ptags.push(setTagId)
        @_setTimestampToNow()
        return true

    isBlipAccessAddsParticipant: (user, actions) ->
        ###
        #проверяем ситуацию: primary-пользователь пишет в топик в который еще не заходил, т.е. еще не добавлен в него
        #see: WaveController.getWaveByUrlEx
        if user.isPrimary()
            ids = user.getAlternativeIds()
            #проверяем, что один из merged-пользователей есть в этом топике, если да, то добавляем primary
            return true if _.any((@getParticipantById(id)[0] for id in ids))
        ###
        return if @getSharedState() != SHARED_STATES.SHARED_STATE_PUBLIC
        return if @hasParticipant(user, true)
        intersection = _.intersection(actions, [ACTIONS.ACTION_COMMENT, ACTIONS.ACTION_WRITE, ACTIONS.ACTION_WRITE_SELF_DOCUMENT, ACTIONS.ACTION_PLUGIN_ACCESS])
        return !!intersection.length

    getTopicCreator: () ->
        iterator = (participant) ->
            return if not participant.hasRole()
            return if participant.isBlocked()
            return participant if participant.isTopicCreator()
        participant = @_participantsMap(iterator)
        return if participant.length then participant[0] else null

    getProcessWaveGettingOp: (user, callback) ->
        ops = []
        if @getSharedState() == SHARED_STATES.SHARED_STATE_LINK_PUBLIC
            ops = ops.concat(@_getAddParticipantsOp(@getTopicCreator(), [user], @getDefaultRole()))
        return callback(null, ops) if not user.isPrimary()
        role = ROLES.ROLE_NO_ROLE
        firstIndex = null
        # ищем и удаляем альтернативные id из участников топика
        for id in user.getAlternativeIds()
            [participant, index] = @getParticipantById(id)
            continue if not participant or participant.isBlocked()
            role = Math.min(participant.role, role)
            if participant.role < ROLES.ROLE_NO_ROLE
                firstIndex = index if firstIndex == null
                console.log("Merge relative deleting participant: #{@id},  #{participant.id} (#{participant.role})")
                participant.addAction(null, ACTIONS.ACTION_DELETE_FROM_TOPIC)
                ops.push(@_getChangeParticipantParamsOp(participant, index, ROLES.ROLE_NO_ROLE, null))
        if firstIndex?
            # ищем и удаляем текущего пользователя из участников топика (случай когда и основной, и альтернативные id находились среди участников топика)
            [participant, index] = @getParticipantById(user.id)
            if participant
                console.log("Merge relative deleting participant (primary): #{@id},  #{participant.id} (#{participant.role})")
                participant.addAction(null, ACTIONS.ACTION_DELETE_FROM_TOPIC)
                removeOp =
                    p: ['participants', index]
                    ld: participant.toObject()
                ops.push(removeOp)
                firstIndex = Math.min(index, firstIndex)
                role = Math.min(participant.role, role)
            # добавляем текущего (основной id) пользователя в топик
            console.log("Merge relative inserting participant: #{@id},  #{user.id} (#{role})")
            participantToAdd = new ParticipantModel(user.id, role, [ALL_PTAG_ID, FOLLOW_PTAG_ID])
            participantToAdd.addAction(null, ACTIONS.ACTION_ADD_TO_TOPIC)
            insertOp =
                p: ['participants', firstIndex]
                li: participantToAdd.toObject()
            ops.push(insertOp)
        callback(null, ops)

    getAddParticipantsOp: (user, participants, role, callback) ->
        ###
        @param user: UserModel
        @param participants: array of UserModel
        @param role: int
        @param callback: function
        ###
        err = @checkPermission(user, ACTIONS.ACTION_ADD_TO_TOPIC)
        return callback(err) if err
        [err, role] = @_getSafetyRole(role, user)
        return callback(err) if err
        ops = @_getAddParticipantsOp(user, participants, role)
        if not ops.length
            err = new WaveError('Participant already added to topic', WAVE_PARTICIPANT_ALREADY_IN)
            return callback(err)
        callback(null, ops)

    _getAddParticipantsOp: (inviter, users, role) ->
        ops = []
        added = []
        offset = @participants.length
        for user in users
            continue if user.isAnonymous()
            id = user.id
            continue if id in added
            [participant, index] = @_getParticipant(user)
            continue if participant and participant.hasRole()
            op = {p: ['participants', if index? then index else offset+ops.length]}
            if participant
                participantToAdd = participant
                participantToAdd.role = role
                op.ld = participant.toObject()
            else
                participantToAdd = new ParticipantModel(id, role, [ALL_PTAG_ID, FOLLOW_PTAG_ID], BLOCKING_STATES.NON_BLOCKED)
            participantToAdd.addAction(inviter, ACTIONS.ACTION_ADD_TO_TOPIC)
            op.li = participantToAdd.toObject()
            added.push(id)
            ops.push(op)
        return ops

    _getSafetyRole: (role, user) ->
        # решили не делать пользователя Creator-ом при добавлении в топик, из которого все удалились (такое добавление возможно для "Public", "Shared by link" и созданных через Google Drive топиков).
        # return [null, ROLES.ROLE_TOPIC_CREATOR] if not @getParticipantsWithRole().length #добавление в топик из которого все удалились
        role = role or @getDefaultRole()
        err = @_isValidConst(role, ROLES)
        return [err, null] if err
        [err, userRole] = @authorizeUser(user)
        userRole = ROLES.ROLE_EDITOR if userRole == ROLES.ROLE_TOPIC_CREATOR
        return [err, null] if err
        return [null, Math.max(userRole, role)]

    getDeleteParticipantsOp: (user, ids, callback) ->
        @_getChangeParticipantsParamsOp(ids, user, ACTIONS.ACTION_DELETE_FROM_TOPIC, ROLES.ROLE_NO_ROLE, null, callback)

    getChangeParticipantsBlockingStateOp: (user, ids, state, callback) ->
        err = @_isValidConst(state, BLOCKING_STATES)
        return callback(err) if err
        @_getChangeParticipantsParamsOp(ids, user, ACTIONS.ACTION_BLOCK_PARTICIPANT, null, state, callback)

    getChangeParticipantsRoleOp: (user, ids, role, callback) ->
        [err, role] = @_getSafetyRole(role, user)
        return callback(err) if err
        @_getChangeParticipantsParamsOp(ids, user, ACTIONS.ACTION_CHANGE_PARTICIPANT_ROLE, role, null, callback)

    _getChangeParticipantsParamsOp: (ids, user, action, role, blockingState, callback) ->
        ids = [ids] if not _.isArray(ids)
        ids = _.uniq(ids)
        ops = []
        for id in ids
            [participant, index] = @getParticipantById(id)
            return callback(new WaveError('Participant is not in topic', WAVE_PARTICIPANT_NOT_IN)) if not participant
            correctedAction = action
            if participant.isTopicCreator()
                correctedAction = ACTIONS.ACTION_MANAGE_TOPIC_CREATOR
            else if user.isEqual(participant)
                correctedAction = ACTIONS.ACTION_MANAGE_SELF
            err = @checkPermission(user, correctedAction)
            return callback(err) if err
            participant.addAction(user, action) #добавляем в лог участника запись о действие над ним (нужно взять изначальное действие)
            ops.push(@_getChangeParticipantParamsOp(participant, index, role, blockingState))
            ops.push(@_getAssignNewCreatorOp()...) if correctedAction == ACTIONS.ACTION_MANAGE_TOPIC_CREATOR
        callback(null, ops)

    _getChangeParticipantParamsOp: (participant, index, role, blockingState) ->
        op = {p: ['participants', index], ld: participant.toObject()}
        if role?
            participant.role = role
        if blockingState?
            participant.blockingState = blockingState
        op.li = participant
        return op

    _getAssignNewCreatorOp: () ->
        [successor, index] = @_getTopicCreatorSuccessor()
        return [] if not successor
        ops = [{p: ['participants', index], ld: successor.toObject()}]
        successor.role = ROLES.ROLE_TOPIC_CREATOR
        ops.push({p: ['participants', 0], li: successor})
        return ops

    _getTopicCreatorSuccessor: () ->
        minRole = ROLES.ROLE_NO_ROLE
        result = [null, null]
        iterator = (participant, index) ->
            return if participant.isTopicCreator()
            return if participant.isBlocked()
            role = participant.role
            return if minRole <= role
            minRole = role
            result = [participant, index]
        @_participantsMap(iterator)
        return result

    hasParticipantById: (id) ->
        [participant, index] = @getParticipantById(id)
        return !!participant

    getParticipantById: (id) ->
        iterator = (participant, index) ->
            return [participant, index] if participant.id == id
        participant = @_participantsMap(iterator)
        return if participant.length then participant[0] else [null, null]

    getSetSharedStateOp: (user, state, defaultRole, callback) ->
        err = @_isValidConst(state, SHARED_STATES)
        err ||= @_isValidConst(defaultRole, ROLES) if defaultRole
        err ||= @checkPermission(user, ACTIONS.ACTION_CHANGE_SHARED_STATE)
        return callback(err) if err
        sharedStateOp =
            p: ['sharedState']
            od: @getSharedState()
            oi: state
        defaultRole = @_calculateDefaultRole() if not defaultRole
        #Если клиент гонит и ставит слишком высокую defaultRole
        defaultRole = ROLES.ROLE_EDITOR if defaultRole == ROLES.ROLE_TOPIC_CREATOR
        defaultRoleOp =
            p: ['defaultRole']
            od: @getDefaultRole()
            oi: defaultRole
        callback(null, [sharedStateOp, defaultRoleOp])

    _calculateDefaultRole: () ->
        sharedState = @getSharedState()
        return ROLES.ROLE_PARTICIPANT if sharedState == SHARED_STATES.SHARED_STATE_PUBLIC
        return ROLES.ROLE_EDITOR if sharedState == SHARED_STATES.SHARED_STATE_LINK_PUBLIC
        return ROLES.ROLE_EDITOR if sharedState == SHARED_STATES.SHARED_STATE_PRIVATE

    _isValidConst: (constValue, availableConsts) ->
        return if constValue in _.values(availableConsts)
        return new WaveError("#{constValue} is invalid value", WAVE_INVALID_PARAM_VALUE)

    isTeamTopic: () ->
        return @topicType == TOPIC_TYPES.TOPIC_TYPE_TEAM

    getOptionByName: (name) ->
        return @_options[name]

    setOptions: (options) ->
        _.extend(@_options, options)

    getGDriveId: -> @gDriveId

module.exports =
    WaveModel: WaveModel
    ParticipantModel: ParticipantModel
