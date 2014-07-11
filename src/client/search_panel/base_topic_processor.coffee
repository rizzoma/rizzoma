BaseSearchProcessor = require('./base_processor').BaseSearchProcessor
{Request} = require('../../share/communication')

class BaseTopicsProcessor extends BaseSearchProcessor
    constructor: (@_rootRouter) ->

    followTopic: (waveId, callback) ->
        request = new Request({waveId: waveId}, callback)
        @_rootRouter.handle('network.wave.followWave', request)

    unfollowTopic: (waveId, callback) ->
        request = new Request({waveId: waveId}, callback)
        @_rootRouter.handle('network.wave.unfollowWave', request)

module.exports =
    BaseTopicsProcessor: BaseTopicsProcessor
    instance: null