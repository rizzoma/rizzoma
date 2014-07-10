ShareDoc = require('share/src/client/doc').Doc
VolnaType = require('share/src/types').volna
async = require('async')

class AverageMan
    constructor: (@_id, @_waveModule, @_world, @_user) ->
        @openTimeout = 2000
        @closeTimeout = 2000

    _postOpToBlip: (shareOp, session, callId, callback) =>
        request =
            user: @_user
            session: session
        blipId = shareOp.doc
        args =
            blipId: blipId
            version: shareOp.v
            op: shareOp.op
            callId: callId
            random: Math.random()
        @_world.addStat('operations posted', 1)
        @_readBlip(blipId) if Math.random() > 0.5
        @_waveModule.postOpToBlip(request, args, callback, session + callId)

    _readBlip: (blipId) ->
        request = {user: @_user}
        args = {blipId: blipId}
        @_waveModule.updateBlipReader(request, args, (err) =>
            return if err
            console.log("Average man #{@_id} read blip #{blipId}")
        )

    _infinityPostOpToRandomBlip: (docs, maxBlipSize, delay) =>
        possibleSymbols = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
        submit = ->
            setTimeout ->
                doc = docs[Math.floor(Math.random() * docs.length)]
                firstBlock = doc.snapshot.content[1]
                if firstBlock?.t.length > maxBlipSize
                    pos = Math.floor(Math.random() * firstBlock.t.length)
                    op = {p: pos + 1, td: firstBlock.t[pos], params: { __TYPE: 'TEXT' }}
                else
                    pos = Math.floor(Math.random() * possibleSymbols.length)
                    symb = possibleSymbols[pos]
                    op = {p: 1, ti: symb, params: { __TYPE: 'TEXT' }}
                doc.submitOp([op])
                submit()
            , Math.random() * delay * 2
        submit()

    _getWave: (waveId, callback) =>
        request = {user: @_user}
        args = {waveId: waveId}
        console.log("Average man #{@_id} is opening wave", waveId)
        @_world.addStat('waves requested', 1)
        @_waveModule.getWaveWithBlips(request, args, (err, data) =>
            return callback(err) if err
            @_world.addStat('waves received', 1)
            console.log("Average man #{@_id} opened wave #{waveId}")
            wave = data.wave
            rootBlipId = wave.snapshot.rootBlipId
            blips = []
            docs = []
            self = @
            connection =
                send: (data, callback) ->
                    console.log("Average man #{self._id} sends op to blip #{data.doc}", data.op)
                    self._postOpToBlip(data, @session, @callId, (err, res) ->
                        console.log("Average man #{self._id} got response for op", err, res)
                        self._world.addStat('operations post responses', 1)
                        callback(err, res)
                    )
            for blip in data.blips
                @_world.addStat('blips received', 1)
                doc = new ShareDoc(connection, blip.docId, blip.v, VolnaType, blip.snapshot)
                docs.push(doc)
                blips.push(blip)
            callback(null, waveId, wave.v, connection, blips, docs)
        )

    _subscribeWave: (waveId, waveVersion, connection, blips, docs, callback) =>
        console.log("Average man #{@_id} is subscribing to wave #{waveId}")
        connection.session = Math.random().toString()
        connection.callId = Math.random().toString()
        docsByDocId = {}
        docsByDocId[doc.name] = doc for doc in docs
        request =
            user: @_user
            callback: (reply) =>
                if reply.err
                    @_world.addStat('wave subscription error', 1)
                    console.error("Average man #{@_id} got error in subscription to #{rootBlip.docId}", reply.err)
                    throw reply.err
                msg = reply.data
                console.log("Average man #{@_id} got new operation", JSON.stringify(msg))
                msg.doc = msg.docId
                @_world.addStat('operations received', 1)
                doc = docsByDocId[msg.docId]
                if not doc
                    console.log 'Got non blip operation'
                    return
                doc._onOpReceived(msg)
            session: connection.session
            callId: connection.callId
        args =
            versions:
                wave:
                    id: waveId
                    version: waveVersion
                blips: {}
        for blip in blips
            args.versions.blips[blip.docId] = blip.v
        @_world.addStat('waves subscribed', 1)
        @_world.addStat('blips subscribed', blips.length)
        @_waveModule.subscribeWaveWithBlips(request, args, (err) =>
            return if not err
            console.error("Average man #{@_id} could not subscribe to wave #{waveId}", err)
            # Не можем здесь вызвать callback(err), посколько уже вызвали callback(null)
            throw err
        )
        setTimeout(() ->
            callback(null, docs, request.sessionId, request.callId)
        , 10
        )

    openWaveAndInfinityPostOpToRootBlip: (waveId, maxBlipSize, delay) ->
        startPosting = (docs, session, callId, callback) =>
            @_world.addStat('average writers', 1)
            console.log("Average man #{@_id} starts posting to random blips of #{waveId}")
            @_infinityPostOpToRandomBlip(docs, maxBlipSize, delay)
        tasks = [async.apply(@_getWave, waveId), @_subscribeWave, startPosting]
        async.waterfall(tasks, (err) =>
            if err
                console.error("Average man #{@_id} got error", err)
            else
                console.log("Average man #{@_id} finished job openWaveAndInfinityPostOpToRootBlip")
        )

    openWaveAndListenToRootBlip: (waveId) ->
        addStat = (callback) =>
            @_world.addStat('average listeners', 1)
        tasks = [async.apply(@_getWave, waveId), @_subscribeWave, addStat]
        async.waterfall(tasks, (err) =>
            if err
                console.error("Average man #{@_id} got error", err)
            else
                console.log("Average man #{@_id} finished job openWaveAndListenToRootBlip")
        )

    _infinitySearch: (delay) =>
        request = {user: @_user}
        args = {queryString: ''}
        @_world.addStat('average search', 1)
        console.log("Average man #{@_id} starting search")
        @_waveModule.searchBlipContent(request, args, (err, data) =>
            if err
                console.error("Average man #{@_id} got error", err)
            else
                console.log("Average man #{@_id} got search result of length #{data.length}")
            nextTimeout = +delay + (Math.random() - 0.5) * delay
            setTimeout(() =>
                @_infinitySearch(delay)
            , nextTimeout)
        )

    infinitySearch: (waveId, delay) ->
        @_world.addStat('average searchers', 1)
        @_getWave(waveId, (err) =>
            if err
                console.error("Average man #{@_id} got error", err)
                return
            @_infinitySearch(delay)
        )

module.exports.AverageMan = AverageMan
