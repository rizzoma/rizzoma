sinon = require('sinon')
testCase = require('nodeunit').testCase;
BaseModule = require('../../share/base_module').BaseModule
ProcedureNotFoundError = require('../../share/exceptions').ProcedureNotFoundError
Request = require('../../share/communication').Request

module.exports =
    BaseModuleTest: testCase
        setUp: (callback) ->
            @module = new BaseModule 'someRouter'
            callback()

        testConstructor: (test) ->
            test.equals @module._rootRouter, 'someRouter', "_rootRouter must be set in constructor"
            test.done()

        testHandleCallMethod: (test) ->
            method = sinon.spy()
            @module.foo = method
            @module.handle 'foo', 'request'
            test.ok method.calledOnce, "Method must be called once"
            test.deepEqual method.args[0], ['request']
            test.done()

        testHandleCallMethodWithException: (test) ->
            callback = sinon.spy()
            request =
                callback: callback
            @module.handle 'notExistingMethod', request
            test.ok callback.calledOnce, "Method must be called once"
            test.ok callback.args[0][0] instanceof ProcedureNotFoundError, "First arg must be exception"
            test.done()
