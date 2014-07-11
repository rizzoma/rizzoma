WaveModule = require("../../wave/module").WaveModule
AverageMan = require('./average_man_helper').AverageMan
{UserCouchProcessor} = require('../../user/couch_processor')
async = require('async')

class World
    constructor: ->
        @_waveModule = new WaveModule()
        @averageMen = []
        @_stats = {}
        @_lastUsedUserNum = 0
        process.on('SIGINT', @_showStats)

    addAverageMen: (num, callback) ->
        tasks = []
        for i in [1..num]
            tasks.push(
                do (i) => (callback) =>
                    @getNewUser((err, user) =>
                        return callback(err) if err
                        @averageMen.push(new AverageMan(i, @_waveModule, @, user))
                        callback(null)
                    )
            )
        async.parallel(tasks, callback)

    createWave: (user, callback) ->
        request = {user}
        @_waveModule.createWave(request, {}, callback)

    createBlip: (user, waveId, callback) ->
        request = {user}
        args = {waveId}
        @_waveModule.createBlip(request, args, callback)

    shareWave: (user, waveId, callback) ->
        console.log "Setting share state to #{waveId}"
        request = {user}
        args = {waveId, sharedState: require('../../wave/constants').WAVE_SHARED_STATE_LINK_PUBLIC}
        @_waveModule.setShareState(request, args, (err, res) ->
            console.log("Share state set", err, res)
            callback(err, res)
        )

    getNewUser: (callback) =>
        @_lastUsedUserNum++
        email = "fakeuser#{@_lastUsedUserNum}@gmail.com"
        UserCouchProcessor.getOrCreateByEmails([email], null, (err, users) ->
            return callback(err) if err
            callback(null, users[email])
        )

    addStat: (key, value) ->
        @_stats[key] ||= 0
        @_stats[key] += value

    _showStats: () =>
        console.log 'Stats:'
        names = Object.keys(@_stats).sort()
        for name in names
            console.log("#{name}: #{@_stats[name]}")
        process.exit()

module.exports = {World}