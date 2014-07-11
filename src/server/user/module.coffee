BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
MergeController = require('./merge_controller').MergeController
PrepareMergeController = require('./prepare_merge_controller').PrepareMergeController
UserController = require('./controller').UserController
ContactsController = require('../contacts/controller').ContactsController

{
    ITEM_INSTALL_STATE_INSTALL
    ITEM_INSTALL_STATE_UNINSTALL
} = require('./constants')

class UserModule extends BaseModule
    ###
    Модуль предоставляющей API для работы с пользователями.
    ###
    constructor: (args...) ->
        super(args..., Response)

    prepareMerge: (request, args, callback) ->
        ###
        Подготавливает пользователей для объединения, которое будет завершено после переходу по ссылке из письма.
        @see: MergeController.merge
        ###
        emailToMerge = args.emailToMerge
        PrepareMergeController.prepareMerge(request.user, emailToMerge, callback)
    @::v('prepareMerge', ['emailToMerge'])

    mergeByOauth: (request, args, callback) ->
        code = args.code
        MergeController.mergeByOauth(request.user, request.session, code, callback)
    @::v('mergeByOauth', ['code'])

    getUsersInfo: (request, args, callback) ->
        ###
        Возвращет профиль пользователя.
        ###
        waveId = args.waveId
        userIds = args.participantIds
        UserController.getUsersInfo(waveId, request.user, userIds, callback)
    @::v('getUsersInfo', ['waveId(not_null)', 'participantIds'])

    getMyProfile: (request, args, callback) ->
        UserController.getMyProfile(request.user, callback)
    @::v('getMyProfile', [])

    getUserContacts: (request, args, callback) ->
        ###
        Возвращет контакты пользователя.
        ###
        ContactsController.getContacts(request.user, callback)
    @::v('getUserContacts')

    setUserSkypeId: (request, args, callback) ->
        user = request.user
        skypeId = args.skypeId
        UserController.setUserSkypeId(user, skypeId, callback)
    @::v('setUserSkypeId', ['skypeId'])

    setUserClientOption: (request, args, callback) ->
        user = request.user
        optName = args.name
        optValue = args.value
        UserController.setUserClientOption(user, optName, optValue, callback)
    @::v('setUserClientOption', ['name', 'value'])

    changeProfile: (request, args, callback) ->
        user = request.user
        email = args.email
        name = args.name
        avatar = args.avatar
        UserController.changeProfile(user, email, name, avatar, callback)
    @::v('changeProfile', ['email', 'name', 'avatar'])

    installStoreItem: (request, args, callback) ->
        ###
        Инсталлирует позицию пользователю.
        ###
        itemId = args.itemId
        UserController.changeItemInstallState(request.user, itemId, ITEM_INSTALL_STATE_INSTALL, callback)
    @::v('installStoreItem', ['itemId(not_null)'])

    uninstallStoreItem: (request, args, callback) ->
        ###
        Деинсталлирует позицию.
        ###
        itemId = args.itemId
        UserController.changeItemInstallState(request.user, itemId, ITEM_INSTALL_STATE_UNINSTALL, callback)
    @::v('uninstallStoreItem', ['itemId(not_null)'])

    giveBonus: (request, args, callback) ->
        ###
        Добавляет пользователю бонус определенного типа.
        ###
        bonusType = args.bonusType
        UserController.giveBonus(request.user, bonusType, callback)
    @::v('giveBonus', ['bonusType'])

module.exports.UserModule = UserModule