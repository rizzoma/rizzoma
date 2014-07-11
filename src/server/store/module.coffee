BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
StoreController = require('./controller').StoreController
PULSE_ACCESS = require('../user/constants').PULSE_ACCESS

{STORE_ITEM_STATE_VISIBLE} = require('../../share/constants')

class StoreModule extends BaseModule
    ###
    Модуль предоставляющей API для работы с магазином.
    ###
    constructor: (args...) ->
        super(args..., Response)

    addItem: (request, args, callback) ->
        category = args.category
        title = args.title
        icon = args.icon
        description = args.description
        topicUrl = args.topicUrl
        weight = args.weight
        url = args.url
        StoreController.addItem(category, title, icon, description, topicUrl, weight, {url}, callback)
    @::v('addItem', ['category', 'title', 'icon', 'description', 'topicUrl', 'weight', 'url'], PULSE_ACCESS)

    editItem: (request, args, callback) ->
        id = args.id
        title = args.title
        icon = args.icon
        description = args.description
        topicUrl = args.topicUrl
        weight = args.weight
        url = args.url
        StoreController.editItem(id, title, icon, description, topicUrl, weight, {url}, callback)
    @::v('editItem', ['id', 'title', 'icon', 'description', 'topicUrl', 'weight', 'url'], PULSE_ACCESS)

    changeItemState: (request, args, callback) ->
        id = args.id
        state = args.state
        StoreController.changeItemState(id, state, callback)
    @::v('changeItemState', ['id', 'state'], PULSE_ACCESS)

    getVisibleItemList: (request, args, callback) ->
        ###
        Возвращает список видимых позиций в той или иной категории.
        ###
        StoreController.getFullItemList(STORE_ITEM_STATE_VISIBLE, callback)
    @::v('getVisibleItemList', [])

    getFullItemList: (request, args, callback) ->
        ###
        Возвращает полный список позиций в той или иной категории.
        ###
        state = args.state
        StoreController.getFullItemList(state, callback)
    @::v('getFullItemList', [])

    getItemsInfo: (request, args, callback) ->
        ###
        Возвращает информацию о позиция.
        ###
        ids = args.ids
        StoreController.getItemsInfo(ids, callback)
    @::v('getItemsInfo', ['ids'])

module.exports.StoreModule = StoreModule
