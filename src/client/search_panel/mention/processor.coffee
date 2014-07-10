{Request} = require('../../../share/communication')
BaseSearchProcessor = require('../base_processor').BaseSearchProcessor

class MentionsProcessor extends BaseSearchProcessor
    constructor: (@_rootRouter) ->
        super(@_rootRouter)

    addRecipientByEmail: (blipId, version, position, email, callback) ->
        params = {blipId, version, position, email}
        request = new Request(params, callback)
        @_rootRouter.handle('network.message.addRecipientByEmail', request)

    send: (blipId, callback) ->
        request = new Request({blipId}, callback)
        @_rootRouter.handle('network.message.send', request)

module.exports =
    MentionsProcessor: MentionsProcessor
    instance: null