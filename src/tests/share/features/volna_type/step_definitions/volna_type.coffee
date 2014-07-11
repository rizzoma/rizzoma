Steps = require('cucumis').Steps
Model = require('share/lib/server/model')
Doc = require('share/lib/client/doc').Doc
NetworkProxy = require('../../network_proxy').NetworkProxy
types = require('share/lib/types')
assert = require('assert')

clone = (o) -> JSON.parse(JSON.stringify(o))
parse = (str) ->
    try
        return JSON.parse(str)
    catch e
        throw new SyntaxError "#{str} is not a proper JSON object"
        
DOC_TYPE = 'volna'
DOC_ID = 'test'

server = clients = null

getServerDoc = (callback) ->
    server.getSnapshot DOC_ID, (err, res) ->
        throw err if err
        callback(res)

applyServerOp = (op, callback) ->
    server.applyOp DOC_ID, op, (err, version) ->
        throw err if err
        callback(version)

setup = ->
    server = new Model()
    clients = []

Steps.Given /^server with (.+)$/, (ctx, obj) ->
    setup()
    obj = parse obj
    server.create DOC_ID, DOC_TYPE, {}, (err) ->
        throw err if err
        getServerDoc (serverDoc) ->
            index = 0
            totalLength = 0
            op =
                v: serverDoc.v
                op: [
                    p: []
                    od: serverDoc.snapshot
                    oi: obj
                ]
                meta: {}
            applyServerOp op, -> ctx.done()

Steps.Given /^client(\d+)$/, (ctx, clientNum) ->
    clientNum--
    getServerDoc (doc) ->
        clients[clientNum] = client = {}
        client.proxy = new NetworkProxy(clientNum)
        client.doc = new Doc(client.proxy, DOC_ID, doc.v, types[DOC_TYPE], doc.snapshot)
        server.listen DOC_ID, doc.v, client.proxy.receive, (err) ->
            throw err if err
            ctx.done()

Steps.When /^client(\d+) submits (.+)$/, (ctx, clientNum, obj) ->
    clientNum--
    obj = parse(obj)
    client = clients[clientNum]
    client.doc.submitOp(obj)
    ctx.done()

Steps.When /^server receives operation (\d+) from client(\d+)$/, (ctx, opNum, clientNum) ->
    clientNum--
    client = clients[clientNum]
    client.proxy.getSentOp opNum, (op) ->
        op = clone op
        applyServerOp op, (version) ->
            # Подтверждение получения операции сервером, отсылаемое клиенту
            client.proxy.receiveResponse {doc: DOC_ID, v: version}
            ctx.done()
    
Steps.Then /^server should send (.+) to client(\d+)$/, (ctx, obj, clientNum) ->
    clientNum--
    obj = parse obj
    client = clients[clientNum]
    client.proxy.getReceivedOp (op) ->
        assert.deepEqual op.op, obj
        client.doc._onOpReceived op
        ctx.done()

Steps.Then /^everyone should have (.+)$/, (ctx, obj) ->
    obj = parse obj
    for client, idx in clients
        try
            assert.deepEqual client.doc.snapshot, obj
        catch e
            e.message = "For client#{idx + 1}:\n#{e.message}"
            throw e
    getServerDoc (doc) ->
        try
            assert.deepEqual doc.snapshot, obj
        catch e
            e.message = "For server:\n#{e.message}"
            throw e
        ctx.done()

Steps.Then /^server should have (.+)$/, (ctx, obj) ->
    obj = parse obj
    getServerDoc (doc) ->
        assert.deepEqual doc.snapshot, obj
        ctx.done()

Steps.Then /^client(\d+) should have (.+)$/, (ctx, clientNum, obj) ->
    clientNum--
    obj = parse obj
    client = clients[clientNum]
    assert.deepEqual client.doc.snapshot, obj
    ctx.done() 

Steps.export(module)
