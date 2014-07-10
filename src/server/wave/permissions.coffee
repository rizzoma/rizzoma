_ = require('underscore')

{
    SHARED_STATE_PUBLIC
    SHARED_STATE_LINK_PUBLIC
    SHARED_STATE_PRIVATE
} = require('./constants').SHARED_STATES

{
    ROLE_EDITOR
    ROLE_PARTICIPANT
    ROLE_READER
    ROLE_TOPIC_CREATOR
    ROLE_ANONYMOUS_READER
} = require('./constants').ROLES

{
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_MANAGE_TOPIC_CREATOR
    ACTION_SET_DEFAULT_FOLDING
} = require('./constants').ACTIONS


{
    DENIAL_REASON_ANONYMOUS
    DENIAL_REASON_BLOCKED
    DENIAL_REASON_NOT_IN_TOPIC
    DENIAL_REASON_ACTION_DENIED
} = require('./constants').DENIAL_REASONS

{
    WaveError
    WAVE_PERMISSION_DENIED
    WAVE_ANONYMOUS_PERMISSION_DENIED
    WAVE_BLOCKED_USER_PERMISSION_DENIED
} = require('./exceptions')

ACCESS_MATRIX = [] #Матрица доступа.

setCells = (sharedState, role, actions) ->
    ###
    Устанавливает разрешения на выполнения действий перечисленных в actions
    для пользователя с ролью role в топике с указанным sharedState
    @param sharedState: int
    @param role: int
    @actions: array
    ###
    ACCESS_MATRIX[sharedState] ?= []
    ACCESS_MATRIX[sharedState][role] ?= []
    ACCESS_MATRIX[sharedState][role][action] = yes for action in actions

#Настройка прав ролей на действия в разных типах топиков
#Публичные топики------------------------------------------------------------------
###
Права создателя топика.
###
setCells(SHARED_STATE_PUBLIC, ROLE_TOPIC_CREATOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_MANAGE_TOPIC_CREATOR
    ACTION_SET_DEFAULT_FOLDING
])

###
Права редактора.
###
setCells(SHARED_STATE_PUBLIC, ROLE_EDITOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_SET_DEFAULT_FOLDING
])

###
Права участника.
###
setCells(SHARED_STATE_PUBLIC, ROLE_PARTICIPANT, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_SET_DEFAULT_FOLDING
])

###
Права читателя.
###
setCells(SHARED_STATE_PUBLIC, ROLE_READER, [
    ACTION_READ
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_PLUGIN_ACCESS
])

###
Права анонимного читателя.
###
setCells(SHARED_STATE_PUBLIC, ROLE_ANONYMOUS_READER, [
    ACTION_READ
])

#Расшаренные по ссылке топики------------------------------------------------------------------
###
Права редактора.
###
###
Права создателя топика.
###
setCells(SHARED_STATE_LINK_PUBLIC, ROLE_TOPIC_CREATOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_MANAGE_TOPIC_CREATOR
    ACTION_SET_DEFAULT_FOLDING
])

setCells(SHARED_STATE_LINK_PUBLIC, ROLE_EDITOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_SET_DEFAULT_FOLDING
])

###
Права участника.
###
setCells(SHARED_STATE_LINK_PUBLIC, ROLE_PARTICIPANT, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_FULL_PROFILE_ACCESS
    ACTION_SET_DEFAULT_FOLDING
])

###
Права читателя.
###
setCells(SHARED_STATE_LINK_PUBLIC, ROLE_READER, [
    ACTION_READ
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_PLUGIN_ACCESS
    ACTION_FULL_PROFILE_ACCESS
])

###
Права анонимного читателя.
###
setCells(SHARED_STATE_LINK_PUBLIC, ROLE_ANONYMOUS_READER, [])

#Приватные топики------------------------------------------------------------------
###
Права создателя топика.
###
setCells(SHARED_STATE_PRIVATE, ROLE_TOPIC_CREATOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_MANAGE_TOPIC_CREATOR
    ACTION_SET_DEFAULT_FOLDING
])

###
Права редактора.
###
setCells(SHARED_STATE_PRIVATE, ROLE_EDITOR, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_WRITE
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_DELETE_FROM_TOPIC
    ACTION_CHANGE_SHARED_STATE
    ACTION_FULL_PROFILE_ACCESS
    ACTION_BLOCK_PARTICIPANT
    ACTION_CHANGE_PARTICIPANT_ROLE
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_SET_DEFAULT_FOLDING
])

###
Права участника.
###
setCells(SHARED_STATE_PRIVATE, ROLE_PARTICIPANT, [
    ACTION_READ
    ACTION_COMMENT
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_FULL_PROFILE_ACCESS
    ACTION_PLUGIN_ACCESS
    ACTION_WRITE_SELF_DOCUMENT
    ACTION_SET_DEFAULT_FOLDING
])

###
Права читателя.
###
setCells(SHARED_STATE_PRIVATE, ROLE_READER, [
    ACTION_READ
    ACTION_MANAGE_SELF
    ACTION_ADD_TO_TOPIC
    ACTION_FULL_PROFILE_ACCESS
    ACTION_PLUGIN_ACCESS
])

###
Права анонимного читателя.
###
setCells(SHARED_STATE_PRIVATE, ROLE_ANONYMOUS_READER, [])

class WavePermissionsChecker
    ###
    Класс, реализующий авторизацию действий пользователя над топиком.
    ###
    constructor: (@_wave) ->

    autorizeAction: (user, action) ->
        ###
        Проверяет, может ли пользователь выполнить запрошенное действие.
        @param user: UserModel
        @param action: int
        @returns: undefined or WaveError
        ###
        actions  =  if _.isArray(action) then action else [action]
        return @_autorizeActions(user, actions)

    _autorizeActions: (user, actions) ->
        ###
        Проверяет, может ли пользователь выполнить запрошенные действие.
        Вернет ошибку, если запрещено хотя бы одно.
        @param user: UserModel
        @param action: int
        @returns: bool
        ###
        [deniedReason, role] = @_wave.authorizeUser(user)
        return @_getError(deniedReason, actions[0]) if deniedReason
        for action in actions
            continue if @_isActionAvailable(role, action)
            return @_getError(DENIAL_REASON_ACTION_DENIED, action)
        return

    _isActionAvailable: (role, action) ->
        return ACCESS_MATRIX[@_wave.getSharedState()][role][action]

    _getError: (denialReason, action) ->
        ###
        Возвращает нужную ошибку.
        @param denialReason: int
        @param action: int
        @returns: WaveError
        ###
        ANONYMOUS_ERROR_MESSAGES = {}
        ANONYMOUS_ERROR_MESSAGES[ACTION_READ] = "Sign in to start collaboration. It`s free!"
        ANONYMOUS_ERROR_MESSAGES[ACTION_COMMENT] = "Anonymous can't comment this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_WRITE] = "Anonymous can't edit this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_CHANGE_SHARED_STATE] = "Anonymous can't edit publicity of this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_ADD_TO_TOPIC] = "Anonymous can't edit participants of this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_DELETE_FROM_TOPIC] = "Anonymous can't edit participants of this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_BLOCK_PARTICIPANT] = "Anonymous can't block participants of this topic"
        ANONYMOUS_ERROR_MESSAGES[ACTION_CHANGE_PARTICIPANT_ROLE] = "Anonymous can't change participant role in this topic"
        LOGGED_USER_ERROR_MESSAGES = {}
        LOGGED_USER_ERROR_MESSAGES[ACTION_READ] = "You are not permitted to view this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_COMMENT] = "You are not permitted to comment this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_WRITE] = "You are not permitted to edit this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_CHANGE_SHARED_STATE] = "You are not permitted to edit publicity of this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_ADD_TO_TOPIC] = "You are not permitted to edit participants of this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_DELETE_FROM_TOPIC] = "You are not permitted to edit participants of this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_BLOCK_PARTICIPANT] = "You are not permitted to block participants of this topic"
        LOGGED_USER_ERROR_MESSAGES[ACTION_CHANGE_PARTICIPANT_ROLE] = "You are not permitted to change participant role in this topic"
        DEFAULT_ERROR_MESSAGES = "You have no permissions for this action in this topic"
        BLOCCKED_USER_ERROR_MESSGAE = "You are blocked and have no permissions for this action in this topic"
        if denialReason == DENIAL_REASON_BLOCKED
            code = WAVE_BLOCKED_USER_PERMISSION_DENIED
            message = BLOCCKED_USER_ERROR_MESSGAE
        if denialReason == DENIAL_REASON_ANONYMOUS
            code = WAVE_ANONYMOUS_PERMISSION_DENIED
            message = ANONYMOUS_ERROR_MESSAGES[action]
        if denialReason == DENIAL_REASON_NOT_IN_TOPIC or denialReason == DENIAL_REASON_ACTION_DENIED
            code = WAVE_PERMISSION_DENIED
            message = LOGGED_USER_ERROR_MESSAGES[action]
        return new WaveError(message or DEFAULT_ERROR_MESSAGES, code)

module.exports.WavePermissionsChecker = WavePermissionsChecker
