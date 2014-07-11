sinon = require('sinon')
testCase = require('nodeunit').testCase;
BaseRouter = require('../../share/base_router').BaseRouter
Request = require('../../share/communication').Request

module.exports =
    BaseModuleTest: testCase
        setUp: (callback) ->
            @router = new BaseRouter 'someRouter'
            callback()

        testHandle: (test) ->
            stubExecuteProcedure = sinon.stub @router, '_executeProcedure'
            
            @router._executeProcedure.withArgs('foo', 'request').returns true
            @router.handle 'foo', 'request'
            
            test.ok @router._executeProcedure.calledOnce, "_executeProcedure must be called once"
            
            stubExecuteProcedure.restore()
            test.done()

        testExecuteProcedureWithShortProcedureName: (test) ->
            stubGetModuleByName = sinon.stub @router, '_getModuleByName'
            stubCall = sinon.stub @router, '_call'
            
            result = @router._executeProcedure 'foo', 'request'
            test.ok !stubGetModuleByName.called, "_getModuleByName must be called never"
            test.ok !stubCall.called, "_call must be called never"
            test.ifError result, "must be returns not true"
            
            stubGetModuleByName.restore()
            stubCall.restore()
            test.done()

        testExecuteProcedureWithUnknownProcedure: (test) ->
            stubGetModuleByName = sinon.stub @router, '_getModuleByName'
            stubCall = sinon.stub @router, '_call'
            
            stubGetModuleByName.withArgs('foo').returns false
            
            result = @router._executeProcedure 'foo.bar', 'request'
            test.ok stubGetModuleByName.calledOnce, "_getModuleByName must be called once"
            test.ok !stubCall.called, "_call must be called never"
            test.ifError result, "must be returns not true"
            
            stubGetModuleByName.restore()
            stubCall.restore()
            test.done()

        testExecuteProcedureCallsProcedure: (test) ->
            stubGetModuleByName = sinon.stub @router, '_getModuleByName'
            stubCall = sinon.stub @router, '_call'
            
            stubGetModuleByName.withArgs('foo').returns 'someModule'
            
            result = @router._executeProcedure 'foo.bar.baz', 'request'
            test.ok stubGetModuleByName.calledOnce, "_getModuleByName must be called once"
            test.ok stubCall.calledOnce, "_call must be called once"
            test.deepEqual stubCall.args[0], ['someModule', 'bar.baz', 'request']
            test.ok result, "must be returns true"
            
            stubGetModuleByName.restore()
            stubCall.restore()
            test.done()

        testCall: (test) ->
            handle = sinon.spy()
            module =
                handle: handle
            @router._call module, 'foo', 'request'
            test.ok handle.calledOnce, "handle must be called once"
            test.deepEqual handle.args[0], ['foo', 'request']
            test.done()

        testAddModule: (test) ->
            @router._addModule('foo', 'bar')
            test.deepEqual @router._moduleRegister, {foo: 'bar'}
            test.done()

        testGetModuleByName: (test) ->
            @router._moduleRegister =
                foo: 'bar'
            result = @router._getModuleByName 'foo'
            test.equal result, 'bar'
            test.done()
