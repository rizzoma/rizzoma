_ = require('underscore')

SHARED_STATES =
    ###
    Состояния публичности топика.
    ###
    SHARED_STATE_PUBLIC:      1 #публичный топик
    SHARED_STATE_LINK_PUBLIC: 2 #расшаренны1й по ссылке топик
    SHARED_STATE_PRIVATE:     3 #приватный топик

ROLES =
    ###
    Возможные роли в системе.
    Внимание!!!! Должны идти по убыванию крутости.
    ###
    ROLE_NO_ROLE:          65536 #нет роли
    ROLE_TOPIC_CREATOR:    1 #создатель топика
    ROLE_EDITOR:           2 #редактор топика (крутой чувак, может все)
    ROLE_PARTICIPANT:      3 #участник топика
    ROLE_READER:           4 #читатель топика
    ROLE_ANONYMOUS_READER: 5 #создатель топика

ACTIONS =
    ###
    Возможные действия пользователя.
    ###
    ACTION_READ:                    1 #право на чтение
    ACTION_COMMENT:                 2 #право на комментирование
    ACTION_WRITE:                   3 #право на запись
    ACTION_MANAGE_SELF:             4 #право на управление своим участником (по факту удаление изтопика)
    ACTION_ADD_TO_TOPIC:            5 #право добавлять новых участников втопик
    ACTION_DELETE_FROM_TOPIC:       6 #право удалять из топика
    ACTION_CHANGE_SHARED_STATE:     7 #право изменять публичность  топика
    ACTION_FULL_PROFILE_ACCESS:     8 #право на доступ к полным профилям
    ACTION_BLOCK_PARTICIPANT:       9 #право блокировать участников
    ACTION_CHANGE_PARTICIPANT_ROLE: 10 #право меня роль участника в топике
    ACTION_PLUGIN_ACCESS:           11 #право работать с плагинами блипа
    ACTION_WRITE_SELF_DOCUMENT:     12 #право редактировать "свой" блип
    ACTION_MANAGE_TOPIC_CREATOR:    13 #право менять права/удалять создателя топика
    ACTION_SET_DEFAULT_FOLDING:     14 #право делать блипы свернутыми/развернутыми по умолчанию

DENIAL_REASONS =
    ###
    Причины отказа в авторизации пользователя/его действия.
    ###
    DENIAL_REASON_ANONYMOUS:     1 #Анонимусу отказано в доступе
    DENIAL_REASON_BLOCKED:       2 #Забаненному пользователю отказано в доступе
    DENIAL_REASON_NOT_IN_TOPIC:  3 #Пользовутель отсутствует в топике
    DENIAL_REASON_ACTION_DENIED: 4 #Действие не разрешено

BLOCKING_STATES =
    ###
    Состояния блокировки пользователя.
    ###
    NON_BLOCKED: 0 #Не заблокирован
    BLOCKED:     1 #Заблокирован

TOPIC_TYPES =
    ###
    Тип топика.
    ###
    TOPIC_TYPE_ORDINARY: 1 #Обычный топик.
    TOPIC_TYPE_TEAM:     2 #Топик для команды.

module.exports =
    SHARED_STATES: SHARED_STATES
    ROLES: ROLES
    ACTIONS: ACTIONS
    DENIAL_REASONS: DENIAL_REASONS
    BLOCKING_STATES: BLOCKING_STATES
    TOPIC_TYPES: TOPIC_TYPES

_.extend(module.exports, SHARED_STATES, ROLES, ACTIONS, DENIAL_REASONS, BLOCKING_STATES, TOPIC_TYPES)

