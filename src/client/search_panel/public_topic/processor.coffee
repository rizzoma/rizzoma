BaseTopicsProcessor = require('../base_topic_processor').BaseTopicsProcessor
{Request} = require('../../../share/communication')

class PublicTopicsProcessor extends BaseTopicsProcessor
    constructor: (@_rootRouter) ->

    followTopic: (waveId, callback) ->
        super(waveId, callback)
        _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make followed public'])

    unfollowTopic: (waveId, callback) ->
        super(waveId, callback)
        _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make unfollowed public'])

module.exports =
    PublicTopicsProcessor: PublicTopicsProcessor
    instance: null
