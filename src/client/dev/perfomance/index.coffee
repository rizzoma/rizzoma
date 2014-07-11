async = require('async')
RootRouter = require('./root_router').PerfomanceNetworkRouter
InlineType = require('../../blip/inlines').InlineType
Request = require('../../../share/communication').Request


class Perfomance
    constructor: (@url='http://localhost:8000/') ->
        @_init()
        
    _init: () ->
        
    _openAllBlips: (_blipProcessor, rootBlipId, callback) ->
        bc = 0
        blipIds = [rootBlipId]
        _recursiveOpenBlip = (blipId, fCallback) =>
            _blipProcessor.openBlip({}, blipId, {}, null, (err, blip) =>
                blipIds.push(blipId)
                content = blip.shareDoc.snapshot.content
                process.stdout.write('.')
                childBlipIds = @_getChildBlipIds(content.childStates)
                if childBlipIds.length
                    for childBlipId in childBlipIds
                        bc++
                        _recursiveOpenBlip(childBlipId, () ->
                            bc--
                            return callback(null, blipIds) if not bc
                        )
                return callback(null, blipIds) if not bc
                return fCallback?()
            )
        _recursiveOpenBlip(rootBlipId)
        
    _getChildBlipIds: (childStates) =>
        blipIds = []
        for state in childStates
            if state.nodeName == InlineType.BLIP
                blipIds.push(state.docId)
            else if state.childStates
                childs = @_getChildBlipIds(state.childStates)
                blipIds = blipIds.concat(childs)
        return blipIds
    
    _closeBlips: (_blipProcessor, blipIds, callback) ->
        tasks = []
        for blipId in blipIds
            tasks.push((callback) ->
                _blipProcessor.closeBlip(blipId, (err, res) ->
                    process.stdout.write('#')
                    callback(null)
                )
            )
        async.parallel(tasks, (err, res) ->
            callback(null)
        )
    
    _initProcessors: (_router) ->
        global.window = {io:{}}
        global.WEB = true
        require('share/webclient/share.uncompressed.js')
        global.sharejs = global.window.sharejs
        WaveProcessor = require('../../wave/processor').WaveProcessor
        global.jQuery = {fn:{}}
        global.$ = () ->
            return {
                ready: () ->
            }
        global.document = {}
        BlipProcessor = require('./blip/processor').PerfomanceBlipProcessor
        _waveProcessor = new WaveProcessor(_router)
        _blipProcessor = new BlipProcessor(_router)
        return [_waveProcessor, _blipProcessor]
    
    _openWave: (_waveProcessor, _blipProcessor, waveId, callback) =>
        try
            tasks = [
                (callback) =>
                    _waveProcessor.openWave(waveId, callback)
                (wave, callback) =>
                    @_openAllBlips(_blipProcessor, wave.snapshot.rootBlipId, callback)
                (blipIds, callback) =>
                    @_closeBlips(_blipProcessor, blipIds, callback)
                (callback) =>
                    _waveProcessor.closeWave(waveId, callback)
            ]
            async.waterfall(tasks, callback)
        catch err
            callback(err)

    _printStatistic: (concurrency, amount, errCount, fullDuration) ->
        console.log("")
        console.log("Concurrency Level: #{concurrency}")
        console.log("Complete requests: #{amount}")
        console.log("Failed requests: #{errCount}")
        console.log("Requests per second: #{(amount/(fullDuration/1000)).toFixed(3)} #/s")
        console.log("Time per request: #{((fullDuration/1000)/amount).toFixed(3)} s")
        console.log("Time taken for tests: #{(fullDuration/1000).toFixed(3)} s")
        
    testOpenWave: (waveId='0_wave_1', concurrency=1, amount=1) ->
        _router = new RootRouter(@url)
        [_waveProcessor, _blipProcessor] = @_initProcessors(_router)
        @_devAuth(_router, (err, expressSessionId) =>
            startAll = new Date().getTime()                
            workCount = amount/concurrency
            workCount = 1 if workCount < 1
            errCount = 0
            worker = (callback) =>
                _router = new RootRouter(@url, expressSessionId)
                [_waveProcessor, _blipProcessor] = @_initProcessors(_router)
                tasks = []
                count = workCount
                while count--
                    tasks.push((callback) =>
                        process.stdout.write('^')
                        @_openWave(_waveProcessor, _blipProcessor, waveId, (err, res) ->
                            process.stdout.write('$')
                            errCount++ if err
                            callback(null)
                        )
                    )
                async.series(tasks, callback)

            tasks = []
            workerCount = if concurrency <= amount then concurrency else amount
            tasks.push(worker) while workerCount--
            async.parallel(tasks, () =>
                fullDuration = new Date().getTime() - startAll
                @_printStatistic(concurrency, amount, errCount, fullDuration)
                process.exit()
            )
        )
    
    _devAuth: (_router, callback) ->
        request = new Request({}, callback)
        request.setProperty('recallOnDisconnect', false)
        _router.handle('network.wave.devAuth', request)
    
    _postOpToBlip: (_blipProcessor, blipId, v, callback) =>
        try
            op = {
                doc: blipId,
                docId: blipId,
                op: [{
                    p: [
                        "content",
                        "childStates",
                        0,
                        "childStates",
                        0,
                        "text",
                        0
                    ],
                    si: "V"
                }],
                v: v
            }
            _blipProcessor._otProcessor._processOpResponse = (err, resp) ->
                process.stdout.write('.')
                callback(err, resp.v)
            _blipProcessor._otProcessor.send(op)
        catch err
            callback(err)
    
    testPostOpToBlip: (blipId='0_blip_1', concurrency=1, amount=1) ->
        _router = new RootRouter(@url)
        [_waveProcessor, _blipProcessor] = @_initProcessors(_router)
        @_devAuth(_router, (err, expressSessionId) =>
            _blipProcessor.openBlip({}, blipId, {}, null, (err, blip) =>
                startAll = new Date().getTime()                
                workCount = amount/concurrency
                workCount = 1 if workCount < 1
                errCount = 0
                worker = (callback) =>
                    _router = new RootRouter(@url, expressSessionId)
                    [_waveProcessor, _blipProcessor] = @_initProcessors(_router)
                    tasks = []
                    count = workCount
                    while count--
                        if count == workCount-1
                            tasks.push((callback) =>
                                process.stdout.write('^')
                                @_postOpToBlip(_blipProcessor, blipId, blip.shareDoc.version, (err, v) ->
                                    process.stdout.write('$')
                                    errCount++ if err
                                    callback(null, v)
                                )
                            )
                        else
                            tasks.push((v, callback) =>
                                process.stdout.write('^')
                                @_postOpToBlip(_blipProcessor, blipId, v, (err, v) ->
                                    process.stdout.write('$')
                                    errCount++ if err
                                    callback(null, v)
                                )
                            )
                    async.waterfall(tasks, callback)

                tasks = []
                workerCount = if concurrency <= amount then concurrency else amount
                tasks.push(worker) while workerCount--
                async.parallel(tasks, () =>
                    fullDuration = new Date().getTime() - startAll
                    @_printStatistic(concurrency, amount, errCount, fullDuration)
                    process.exit()
                )
            )
        )

module.exports =
    Perfomance: Perfomance