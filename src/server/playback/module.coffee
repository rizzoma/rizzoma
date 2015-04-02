BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
PlaybackController = require('./controller').PlaybackController


class PlaybackModule extends BaseModule

    constructor: (args...) ->
        super(args..., Response)

    getPlaybackData: (request, args, callback) ->
        waveId = args.waveId
        blipId = args.blipId
        user = request.user
        PlaybackController.getPlaybackData(waveId, blipId, user, callback)
    @::v('getPlaybackData', ['waveId(not_null)', 'blipId(not_null)'])

    getBlipForPlayback: (request, args, callback) ->
        blipId = args.blipId
        PlaybackController.getBlipForPlayback(blipId, request.user, callback)
    @::v('getBlipForPlayback', ['blipId(not_null)'])

    getPlaybackOps: (request, args, callback) ->
        blipId = args.blipId
        offset = args.offset
        PlaybackController.getPlaybackOps(blipId, offset, request.user, callback)
    @::v('getPlaybackOps', ['blipId(not_null)', 'offset(not_null)'])


module.exports.PlaybackModule = PlaybackModule