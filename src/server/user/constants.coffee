_ = require('underscore')
BONUS_TYPES = require('../../share/constants').BONUS_TYPES
{BONUS_TYPE_LINKEDIN_LIKE, BONUS_TYPE_TEAM} = require('../../share/constants')


STORE_ITEM_INSTALL_STATE =
    ###
    Статусы наличия позиции из магазина у пользователя.
    ###
    ITEM_INSTALL_STATE_INSTALL:     1
    ITEM_INSTALL_STATE_UNINSTALL:   2

PREMISSIONS =
    ###
    Права пользователя в системе
    Могут быть степенми двойки (используется битовая маска)
    ###
    NO_PREMISSIONS: 0 #обычный пользователь
    PULSE_ACCESS:   1 #доступ к пуьсу
    DB_EXPORT:      2 #экспорт данных из БД

BONUS_AMOUNTS = {}
BONUS_AMOUNTS[BONUS_TYPE_LINKEDIN_LIKE] = 1024 * 1024 * 1024
BONUS_AMOUNTS[BONUS_TYPE_TEAM] = 10 * 1024 * 1024 * 1024

module.exports =
    ANONYMOUS_ID: '0_u_0'
    #Причина создания пользователя (нужно для аналитики).
    CREATION_REASON_AUTH: 'auth'
    CREATION_REASON_IMPORT: 'import'
    CREATION_REASON_ADD: 'add'
    CREATION_REASON_MERGE: 'merge'
    CREATION_REASON_UNKNOWN: 'unknown'
    MERGE_DIGEST_DELIMITER: '!'
    MERGE_STRATEGY_NAME_PREFIX: 'merge-'
    STORE_ITEM_INSTALL_STATE: STORE_ITEM_INSTALL_STATE
    PREMISSIONS: PREMISSIONS
    BONUS_TYPES: BONUS_TYPES
    BONUS_AMOUNTS: BONUS_AMOUNTS
    BONUS_TYPE_LINKEDIN_LIKE: BONUS_TYPE_LINKEDIN_LIKE
    BONUS_TYPE_TEAM: BONUS_TYPE_TEAM

_.extend(module.exports, STORE_ITEM_INSTALL_STATE, PREMISSIONS)
