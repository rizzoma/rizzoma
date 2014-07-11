BaseTopicsProcessor = require('../base_topic_processor').BaseTopicsProcessor
{Request} = require('../../../share/communication')

class TopicsProcessor extends BaseTopicsProcessor
    constructor: (@_rootRouter) ->

    followTopic: (waveId, callback) ->
        super(waveId, callback)
        _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make followed'])

    unfollowTopic: (waveId, callback) ->
        super(waveId, callback)
        _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make unfollowed'])

module.exports =
    TopicsProcessor: TopicsProcessor
    instance: null
