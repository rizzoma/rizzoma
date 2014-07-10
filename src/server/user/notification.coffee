IdUtils = require('../utils/id_utils').IdUtils
Conf = require('../conf').Conf

# соответствие настроек хранимых в БД с типами связи
DB_TO_COMMUNICATION_TYPES = {
    "smtp": "email"
    "xmpp": "gtalk"
}
# соответствие типов связи названиям полей, хранящимся в БД
COMMUNICATION_TYPES_TO_DB = {
    "email": "smtp"
    "gtalk": "xmpp"
}

SYSTEM_TYPES = [
    "register_confirm"
    "forgot_password"
    "payment_blocked"
    "payment_fault"
    "payment_no_card"
    "payment_success"
]

class UserNotification
    ###
    Хранит настройки оповещений пользователя
    ###
    constructor: (@id=null, @state=null) ->
        # { type: {transport1: true, transport2: true}
        @_settings = {}
        return

    generateId: () ->
        @id = IdUtils.getRandomId(8)

    getEnabledCommunicationTypes: (type) ->
        return [] if @state == 'deny-all' and type not in SYSTEM_TYPES
        typeSettings = @getSettings()[type]
        return [] if not typeSettings
        return (DB_TO_COMMUNICATION_TYPES[option] for option, enabled of typeSettings when enabled)

    clearSettings: () ->
        ###
        Запрещает все транспорты для всех типов оповещений
        ###
        @_settings = {}
        rules = Conf.getNotificationConf().getCommunicationTypes()
        for notificationType, communicationTypes of rules
            @_settings[notificationType] = {} if not @_settings[notificationType]
            for communicationType in communicationTypes
                dbOption = COMMUNICATION_TYPES_TO_DB[communicationType]
                @_settings[notificationType][dbOption] = false

    getSettings: () ->
        ###
        Возвращает настройки нотификаций в формате, в котором они сохраняются в БД
        ###
        rules = Conf.getNotificationConf().getCommunicationTypes()
        settings = {}
        for notificationType, communicationTypes of rules
            settings[notificationType] = {}
            for communicationType in communicationTypes
                dbOption = COMMUNICATION_TYPES_TO_DB[communicationType]
                settings[notificationType][dbOption] = @getOption(notificationType, dbOption)
        return settings

    getOption: (type, transport) ->
        ###
        Возвращает значение одной опции
        Используются типы хранимые в бд
        Затевается для daily и weekly changes digest
        ###
        # системные типы всегда включены
        return true if type in SYSTEM_TYPES
        return false if @state == 'deny-all'
        return !!(type != 'daily_changes_digest' and type != 'new_comment') if not @_settings
        if type == 'daily_changes_digest'
            if not @_settings['weekly_changes_digest'] or @_settings['weekly_changes_digest'][transport] != false
                return false
            if not @_settings['daily_changes_digest'] or @_settings['daily_changes_digest'][transport] != true
                return false
        if type == 'new_comment'
            return !!(@_settings[type] and @_settings[type][transport] == true)
        return !!(not @_settings[type] or @_settings[type][transport] != false)

    setOption: (type, transport, value) ->
        ###
        Устанавливает значение одной опции
        Используются типы хранимые в бд
        если переменная @_settings не создана создает ее
        ###
        @_settings = {} if not @_settings
        @_settings[type] = {} if not @_settings[type]
        @_settings['weekly_changes_digest'][transport] = false if value == true and type == 'daily_changes_digest'
        @_settings['daily_changes_digest'][transport] = false if value == true and type == 'weekly_changes_digest'
        @_settings[type][transport] = value

    setSettings: (settings) ->
        ###
        Устанавливает настройки нотификаций
        @param settings настройки нотификаций, названия полей как в БД
        ###
        @_settings = settings

    setDefaultSettings: () ->
        ###
        Выставляет настройки по умолчанию для новых пользователей
        Вызывается при первом логине пользователя
        ###
        #установми новому пользоателю ежедневный дайджест по умолчанию
        settings = @getSettings()
        settings.weekly_changes_digest.smtp = false
        settings.daily_changes_digest.smtp = true
        settings.new_comment.smtp = true
        @setSettings(settings)


module.exports =
    UserNotification: UserNotification
    DB_TO_COMMUNICATION_TYPES: DB_TO_COMMUNICATION_TYPES
    COMMUNICATION_TYPES_TO_DB: COMMUNICATION_TYPES_TO_DB