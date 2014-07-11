BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
GtagSearchController = require('./search_controller').GtagSearchController

TAGS_EXISTS_TAG = require('./model').TAGS_EXISTS_TAG

class GTagModule extends BaseModule
    ###
    Модуль предоставляющей API работы с тегами.
    ###
    constructor: (args...) ->
        super(args..., Response)

    getGTagList: (request, args, callback) ->
        user = request.user
        GtagSearchController.executeQuery(user, callback)
    @::v('getGTagList')

module.exports.GTagModule = GTagModule
