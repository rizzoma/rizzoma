async = require('async')
World = require('./world_helper').World
world = new World()

runWriter = (man, options, waveId) ->
    man.openWaveAndInfinityPostOpToRootBlip(
        waveId,
        options['max-blip-size'] || 10,
        options['op-delay'] || 2000
    )

runReader = (man, waveId) ->
    man.openWaveAndListenToRootBlip(waveId)

runSearcher = (man, options, waveId) ->
    man.infinitySearch(waveId, options['search-delay'] || 60000)

startTest = (readers, writers, searchers, options, waveId) ->
    delta = 0
    for man, i in world.averageMen
        if i < writers
            runAverageMan = async.apply(runWriter, man, options, waveId)
        else if i < writers + readers
            runAverageMan = async.apply(runReader, man, waveId)
        else
            runAverageMan = async.apply(runSearcher, man, options, waveId)

        if options['hard-start']
            runAverageMan()
        else
            setTimeout(runAverageMan, delta)
            delta += 10

createSharedWave = (blipCount, callback) ->
    async.waterfall([
        (callback) -> world.getNewUser(callback)
        (user, callback) ->
            world.createWave(user, (err, waveId) ->
                return callback(err) if err
                console.log "Test wave #{waveId} created"
                tasks = [(callback) -> world.shareWave(user, waveId, callback)]
                for i in [1..blipCount-1]
                    tasks.push((callback)->
                        world.createBlip(user, waveId, callback)
                    )
                async.parallel(tasks, (err) ->
                    return calllback(err) if err
                    callback(null, waveId)
                )
            )
    ], callback)

getOptionNum = (option, defaultOption) ->
    if isNaN(+option) then defaultOption else +option

module.exports = (options, callback) ->
    blipCount = (+options['blip-count']) || 1
    createSharedWave(blipCount, (err, waveId) ->
        if err
            return console.error("Could not created shared test wave", err)
        console.log("Created shared test wave #{waveId} with #{blipCount} blips")
        writers = getOptionNum(options['average-men-writers'], 2)
        readers = getOptionNum(options['average-men-readers'], 0)
        searchers = getOptionNum(options['average-men-searchers'], 0)
        console.log("Creating #{writers} average writers, #{readers} average readers, #{searchers} average searchers")
        world.addAverageMen(readers+writers+searchers, (err, callback) ->
            startTest(readers, writers, searchers, options, waveId)
        )
    )
