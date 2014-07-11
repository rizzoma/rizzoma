testCase = require('nodeunit').testCase;
Convertible = require('../../share/communication').Convertible
Request = require('../../share/communication').Request
Response = require('../../share/communication').Response

module.exports =
	ConvertibleTest: testCase
		setUp: (callback) ->
			@obj = new Convertible()
			callback()

		tearDown: (callback) ->
			@obj._properties = []
			callback()

		testConstructor: (test) ->
			test.deepEqual @obj._properties, [], "_properties must be empty"
			test.done()

		testSetProperty: (test) ->
			@obj.setProperty 'foo', 'bar'
			test.deepEqual @obj._properties, ['foo'], "must add 1st arg into _properties"
			test.equal @obj.foo, 'bar', "must be equal"
			test.done()

		testSerialize: (test) ->
			@obj.setProperty 'foo', 'bar'
			@obj.privateProperty = 'baz'
			result = @obj.serialize()
			test.deepEqual result, {foo: 'bar'}, "must return only propertys added using setProperty"
			test.done()


	RequestTest: testCase
		setUp: (callback) ->
			@request = new Request({foo: 'bar'}, 'someFunc')
			callback()

		testConstructor: (test) ->
			test.deepEqual @request.args, {foo: 'bar'}, "args must be set in constructor"
			test.equal @request.callback, 'someFunc', "callback must be set in constructor"
			test.deepEqual @request._properties, ['args'], "args must be in _properties"
			test.done()


	ResponseTest: testCase
		setUp: (callback) ->
			@response = new Response({foo: 'bar'})
			callback()

		testConstructor: (test) ->
			test.deepEqual @response.data, {foo: 'bar'}, "data must be set in constructor"
			test.deepEqual @response._properties, ['data'], "data must be in _properties"
			test.done()
