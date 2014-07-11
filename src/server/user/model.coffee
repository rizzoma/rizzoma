_ = require('underscore')
Model = require('../common/model').Model
DateUtils = require('../utils/date_utils').DateUtils
UserUtils = require('./utils').UserUtils
ANONYMOUS_ID = require('./constants').ANONYMOUS_ID
Conf = require('../conf').Conf
getUserInitials = require('../../share/user/utils').getUserInitials
ContactModel = require('../contacts/model').ContactModel
UserNotification = require('./notification').UserNotification
InvalidBonusType = require('./exceptions').InvalidBonusType

CREATION_REASON_UNKNOWN = require('./constants').CREATION_REASON_UNKNOWN
NO_PREMISSIONS = require('./constants').NO_PREMISSIONS

BLOCKED = require('../wave/constants').BLOCKED
NON_BLOCKED = require('../wave/constants').NON_BLOCKED

BONUS_TYPES = require('./constants').BONUS_TYPES
BONUS_AMOUNTS = require('./constants').BONUS_AMOUNTS
BONUS_TYPE_TEAM = require('./constants').BONUS_TYPE_TEAM

{
    ITEM_INSTALL_STATE_INSTALL
    ITEM_INSTALL_STATE_UNINSTALL
} = require('./constants')

DEFAULT_UPLOAD_SIZE_LIMIT = Conf.getUploadSizeLimit()

STORE_ITEM_INSTALLED = 1
STORE_ITEM_UNINSTALLED = 2

DEFAULT_STORE_ITEMS = Conf.getStoreItemsInstalledByDefalult()

DEFAULT_MONTH_TEAM_TOPIC_TAX = Conf.getPaymentConf().getMonthTeamTopicTax

class UserModel extends Model
    ###
    Модель пользователя.
    ###
    constructor: (@id=null, @email=null, @normalizedEmails=[], @name=null, @avatar=null) ->
        @lastActivity = null
        @lastVisit = null
        @firstVisit = null
        @firstVisitNotificationSent = null
        @creationDate = null
        @creationReason = CREATION_REASON_UNKNOWN
        @creationReferer = null
        @notification = new UserNotification()
        @lastDigestSent = null
        @timezone = null
        @devMode = null
        @_uploadSizeLimit = null #если null - берем значение поумолчанию из настроек
        @blockingState = NON_BLOCKED
        @initials = @getInitials()
        @mergingValidationData = {}
        @creationChannel = 'bylink' # с какого канала пришел
        @creationLanding = 'unknown' # с какого лэндинга пришел
        @skypeId = ''
        @clientPreferences = {}
        @_mergedWith = null
        @_mergeDate = null
        @_alternativeIds = []
        @_externalIds = {}
        @_installedStoreItems = {}
        @_permissions = NO_PREMISSIONS
        @_bonuses = {}
        @_monthTeamTopicTax = null
        @_cardInfo = []
        @_paymentLog = []
        @_trialStartDate = null
        @gDrive = null
        super('user')

    getAlternativeIds: () ->
        return @_alternativeIds

    getAllIds: () ->
        @_alternativeIds.concat(@id)

    setAlternativeIds: (ids=[]) ->
        @_alternativeIds = ids if ids.length

    isEqual: (user) ->
        ###
        @param user: UserModel || string
        ###
        id = if _.isString(user) then user else user.id
        return id in @getAllIds()

    inList: (list) ->
        ###
        В списке есть данный пользователь.
        ###
        for user in list
            return true if @isEqual(user)
        return false

    getNormalizedEmail: () ->
        return UserUtils.normalizeEmail(@email)

    setEmail: (email) ->
        return if not email
        @email =  email
        email = UserUtils.normalizeEmail(email)
        @normalizedEmails.push(email) if email not in @normalizedEmails

    getNotMyEmails: (emails) ->
        ###
        Возвращает адреса, которые не находятся у пользователя в normalizedEmails
        ###
        return (email for email in emails when UserUtils.normalizeEmail(email) not in @normalizedEmails)

    isMyEmail: (email) ->
        ###
        email есть в normalizedEmails
        ###
        return UserUtils.normalizeEmail(email) in @normalizedEmails

    setName: (name) ->
        @name = name if name

    setAvatar: (avatar) ->
        @avatar = avatar if avatar

    setTimezone: (timezone) ->
        @timezone = timezone if timezone

    toObject: (fullInfo=false) ->
        res =
            id: @id
            name: @name
            avatar: @avatar
            blockingState: @blockingState
            initials: @getInitials()
            mergedIds: @getAllIds()
            timezone: @timezone
        if fullInfo
            res.email = @email
            res.skypeId = @skypeId
        return res

    toContact: () ->
        return new ContactModel(@email, null, @name, @avatar)

    isAnonymous: () ->
        return not @id or @id == ANONYMOUS_ID

    getInitials: ->
        getUserInitials(@avatar, @name)

    setVisitCondition: () ->
        @_updateTimeProperty('lastVisit')
        @updateLastActivity()

    setCreationCondition: (reason) ->
        @creationReason = reason if reason
        @_updateTimeProperty('creationDate')

    setFirstAuthCondition: (referer, channel='bylink', landing='unknown') ->
        @creationReferer = referer
        @creationChannel = channel
        @creationLanding = landing
        @_updateTimeProperty('firstVisit')

    getContactsId: ()->
        ###
        Делает из id юзверя id документа с контактами (0_u_xxx превращает в 0_c_xxx)
        ###
        return @id.replace('_u_', '_c_')

    isBlocked: () ->
        return @blockingState == BLOCKED

    getUploadSizeLimit: () ->
        ###
        Возвращает ограничение на суммарный размер аттачей.
        @returns: int
        ###
        return @_uploadSizeLimit or DEFAULT_UPLOAD_SIZE_LIMIT

    setUploadSizeLimit: (limit) ->
        ###
        Устанавливает значение ограничения на суммарный размер аттачей.
        @param limit: int
        ###
        console.info("Upload size limit was changed", @id, @_uploadSizeLimit, limit)
        @_uploadSizeLimit = limit

    isUploadSizeLimitDefault: () ->
        ###
        Возвращает дефолтное ли значение у лимита загрузок.
        @returns: bool
        ####
        return _.isNull(@_uploadSizeLimit)

    updateLastActivity: () ->
        @_updateTimeProperty('lastActivity')

    _updateTimeProperty: (name) ->
        @[name] = DateUtils.getCurrentTimestamp()


    isPrimary: () ->
        return not @_mergedWith and @_alternativeIds.length

    isMerged: () ->
        return @_mergedWith and not @_alternativeIds.length

    getPrimaryId: () ->
        return if not @isMerged()
        console.log "Bugcheck. Merged user without '_mergedWith' #{@id}" if not @_mergedWith
        return @_mergedWith

    makePrimary: (mergedUsers) ->
        return if @isMerged()
        limitList = [@_uploadSizeLimit]
        lastActivityList = [@lastActivity]
        lastVisitList = [@lastVisit]
        firstVisitNotificationSentList = [@firstVisitNotificationSent]
        creationDateList = [@creationDate]
        lastDigestSentList = [@lastDigestSent]
        permissions = 0
        for user in mergedUsers
            @_alternativeIds.push(user.id)
            @normalizedEmails = @normalizedEmails.concat(user.normalizedEmails)
            @_cardInfo = @_cardInfo.concat(user.getCardInfo())
            @_paymentLog = @_paymentLog.concat(user.getPaymentLog())
            limitList.push(user.getUploadSizeLimit()) if not user.isUploadSizeLimitDefault()
            lastActivityList.push(user.lastActivity)
            lastVisitList.push(user.lastVisit)
            firstVisitNotificationSentList.push(user.firstVisitNotificationSent)
            creationDateList.push(user.creationDate)
            lastDigestSentList.push(user.lastDigestSent)
            permissions |= user.getPermissions()
        @setUploadSizeLimit(Math.max(limitList...))
        @_cardInfo.sort((x, y) -> return x.creationDate > y.creationDate)
        @_paymentLog.sort((x, y) -> return x.date > y.date)
        @lastActivity = Math.max(lastActivityList...)
        @lastVisit = Math.max(lastVisitList...)
        @firstVisitNotificationSent = Math.min(firstVisitNotificationSentList...)
        @creationDate = Math.min(creationDateList...)
        @lastDigestSent = Math.max(lastDigestSentList...)
        @initials = @getInitials()
        @setPermissions(permissions)

    makeMerged: (primaryUserId) ->
        if @isPrimary()
            @_alternativeIds = []
            @normalizedEmails = []
            @setEmail(@email)
        @_mergedWith = primaryUserId
        @_mergeDate = DateUtils.getCurrentTimestamp()

    setClientOption: (name, value) ->
        ###
        Устанавливает настройку клиента
        ###
        @clientPreferences = {} if not @clientPreferences
        return false if @clientPreferences[name] == value
        @clientPreferences[name] = value
        return true

    getClientOption: (name) ->
        ###
        Возвращает настройку клиента
        ###
        return null if not @clientPreferences
        return @clientPreferences[name]

    getClientPreferences: () ->
        ###
        Возвращает настройки клиента
        ###
        return @clientPreferences

    setClientPreferences: (prefs) ->
        ###
        Устанавливает настройки клиента
        ###
        @clientPreferences = prefs

    setExternalId: (source, id) ->
        @_externalIds[source] = id if source and id

    getExternalIds: () ->
        return @_externalIds

    _getStoreItems: () ->
        ###
        Добавляет поумолчанию позиции.
        ###
        for id in DEFAULT_STORE_ITEMS
            continue if @_installedStoreItems[id]
            @_installedStoreItems[id] = STORE_ITEM_INSTALLED
        return @_installedStoreItems

    getInstalledStoreItems: () ->
        return (id for own id, state of @_getStoreItems() when state == STORE_ITEM_INSTALLED)

    installStoreItem: (item) ->
        ###
        Добавляет позицию из магазина в список установленных.
        @param id: string
        @returns: bool
        ###
        id = item.getId()
        return false if @_getStoreItems()[id] == STORE_ITEM_INSTALLED
        @_installedStoreItems[id] = STORE_ITEM_INSTALLED
        return true

    uninstallStoreItem: (item) ->
        ###
        Удаляет позицию из магазина из списокв установленных.
        @param id: string
        @returns: bool
        ###
        id = item.getId()
        return false if @_getStoreItems()[id] !=  STORE_ITEM_INSTALLED
        @_installedStoreItems[id] =  STORE_ITEM_UNINSTALLED
        return true

    getPermissions: () ->
        return @_permissions

    setPermissions: (permissions) ->
        @_permissions = permissions if permissions

    checkPermissions: (action) ->
        ###
        Проверяет доступно ли пользователю действие.
        @param action: int
        @returns: bool
        ###
        return @_permissions & action

    giveBonus: (bonusType) ->
        ###
        Добавляет пользователю бонус определенного типа.
        Если такой бонус уже есть ничегоне произойдет, changed будет false
        @param bonusType: int
        @returns: [err: Error, changed: bool]
        ###
        return [new InvalidBonusType("Bonus type #{bonusType} is invalid"), false] if bonusType not in BONUS_TYPES
        return @_setBonus(bonusType, BONUS_AMOUNTS[bonusType])

    setTeamBonus: (url) ->
        # если пользователя добавили в team-топик, то считаем, что он пользователь типа Business и ему не нужно показывать диалог выбора типа аккаунта
        @setClientOption('isAccountTypeSelected', true)
        return @_setBonus(@_getTeamBonusType(url), BONUS_AMOUNTS[BONUS_TYPE_TEAM])

    unsetTeamBonus: (url) ->
        return @_setBonus(@_getTeamBonusType(url), -BONUS_AMOUNTS[BONUS_TYPE_TEAM])

    _getTeamBonusType: (url) ->
        return "#{BONUS_TYPE_TEAM}_#{url}"

    _setBonus: (bonusType, bonusSpace) ->
        ###
        Добавляет/удаляет бонус и изменяет доступный лимит загрузок.
        @param bonusType: int
        @param bonusSpace: int - если >= 0 бонус будет добавлен, иначе удален.
        ###
        if bonusSpace >= 0
            return [null, false] if @_hasBonus(bonusType)
            @_bonuses[bonusType] = true
        else
            return [null, false] if not @_hasBonus(bonusType)
            @_bonuses[bonusType] = false
        limit = @getUploadSizeLimit() + bonusSpace
        #На всякий случай обнуляем значение. @see: @getUploadSizeLimit
        limit = null if limit < DEFAULT_UPLOAD_SIZE_LIMIT
        @setUploadSizeLimit(limit)
        return [null, true]

    _hasBonus: (bonusType) ->
        ###
        Проверяет, есть ли бонус данного типа.
        @param bonusType: int
        @returns: bool
        ###
        return !!@_bonuses[bonusType]

    getActiveBonusTypes: ->
        (type for type, _ of @_bonuses when @_hasBonus(type))

    isAccountTypeSelected: () ->
        return @getClientOption('isAccountTypeSelected')

    setCardInfo: (id, type, holderName, last4, expMonth, expYear) ->
        creationDate = DateUtils.getCurrentTimestamp()
        card = @getCard()
        return false if card and card.id == id
        @_cardInfo.push({id, type, holderName, last4, expMonth, expYear, creationDate})
        return true

    getCardInfo: () ->
        return @_cardInfo or []

    getCard: () ->
        return if not @_cardInfo.length
        return @_cardInfo.slice(-1)[0]

    getCardId: () ->
        return @getCard()?.id

    getMonthTeamTopicTax: () ->
        ###
        Возвращает стоимость одного месяца нахождения в team-топике.
        @returns: float
        ###
        return @_monthTeamTopicTax or DEFAULT_MONTH_TEAM_TOPIC_TAX

    addPaymentLog: (chargeErr, amounts, transactionFinished) ->
        ###
        Добавляет лог о платеже пользователя.
        ###
        for own topicId, value of amounts
            logItem =
                reason: topicId
                amount: value
                date: DateUtils.getCurrentTimestamp()
                cardId: @getCardId()
            logItem.err = {message: chargeErr.message, name: chargeErr.name} if chargeErr
            logItem.transactionFinished = !!transactionFinished
            @_paymentLog.push(logItem)

    getPaymentLog: () ->
        return @_paymentLog or []

    isLastTransactionFinished: (topicId) ->
        len = @_paymentLog.length - 1
        while len >= 0
            item = @_paymentLog[len]
            len--
            continue if item.reason != topicId
            return item.transactionFinished
        return true

    getOrCreateTrialStartDate: () ->
        @_trialStartDate = DateUtils.getCurrentDate() if not @_trialStartDate
        return @_trialStartDate

    getDriveInfoByPermissionId: (permissionId) ->
        ids = @gDrive?.ids
        return [] if not ids
        info = []
        for own id, val of ids
            continue if val.permissionId isnt permissionId
            info.push(val)
        info


class SuperUserModel extends UserModel
    constructor: (id) ->
        super(id)

module.exports =
    UserModel: UserModel
    SuperUserModel: SuperUserModel
