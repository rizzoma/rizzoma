sinon = require('sinon')
testCase = require('nodeunit').testCase
Request = require('../../../share/communication').Request
dataprovider = require('dataprovider')

module.exports =
    OtProcessorTest: testCase
        setUp: (callback) ->
            @sharejs = global['sharejs']
            global['sharejs'] = {}
            @OtProcessor = require('../../../client/ot/processor').OtProcessor
            callback()

        tearDown: (callback) ->
            global['sharejs'] = @sharejs
            callback()

        testSend: (test) ->
            docId = 'docId'
            op =
                doc: docId
            testCode = (done, op, callback) =>
                obj =
                    send: ->
                otProcessor = new @OtProcessor obj.send
                otProcessorMock = sinon.mock otProcessor
                otProcessorMock
                    .expects('_send')
                    .once()
                    .withArgs(docId, op, otProcessor._opSendCallback)
                send = otProcessor.send op, callback
                if callback
                    test.ok send?
                else
                    test.equal send, undefined
                otProcessorMock.verify()
                otProcessorMock.restore()
                done()
            dataprovider test, [[op, false], [op, true]], testCode

        testOpen: (test) ->
            docId = 'docId'
            testCode = (done, exp, docId) =>
                callObj =
                    callback: ->
                callObjMock = sinon.mock callObj
                docs =
                    'docId': true
                    'aaaa': true
                if exp isnt 'func'
                    callObjMock
                        .expects('callback')
                        .once()
                        .withArgs(docs[docId])
                obj =
                    send: ->
                otProcessor = new @OtProcessor obj.send
                otProcessor.docs = docs
                res = otProcessor.open docId, callObj.callback
                if exp is 'func'
                    test.ok res instanceof Function
                else
                    test.equal exp, res
                    callObjMock.verify()
                    callObjMock.restore()
                done()
            dataprovider test, [
                ['func', null],
                ['func', 'null'],
                [undefined, 'docId']
            ], testCode
