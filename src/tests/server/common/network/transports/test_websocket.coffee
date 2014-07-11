sinon = require('sinon')
testCase = require('nodeunit').testCase;
Websocket = require('../../../../../server/common/network/transports/websocket')

module.exports =
	WebsocketTest: testCase
		setUp: (callback) ->
			sinon.stub Websocket.prototype, '_init'
			@spyHandle = sinon.spy()
			@websocket = new Websocket 'rootRouter', 'io'
			callback()
		
		tearDown: (callback) ->
			Websocket.prototype._init.restore()
			callback()

		testSendToClient: (test) ->
			stubEmit = sinon.spy()
			session =
				emit: stubEmit
			stubSerialize = sinon.stub()
			response =
				serialize: stubSerialize
			stubSerialize.returns 'response'
				
			@websocket._sendToClient session, response
			
			test.ok stubEmit.calledOnce, "emit must be acced once"
			test.deepEqual stubEmit.args[0], ['message', 'response']
			test.ok stubSerialize.calledOnce
			test.done()
