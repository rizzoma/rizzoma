testCase = require('nodeunit').testCase
sinon = require('sinon')

WaveExportMarkupBuilder = require('../../../server/export/wave').WaveExportMarkupBuilder
    
module.exports =
    WaveExportMarkupBuilderTest: testCase

        setUp: (callback) ->
            @_builder = new WaveExportMarkupBuilder()
            callback()

        testGetUserInfoByIdIfNotFound: sinon.test (test) ->
            sinon.stub(@_builder, '_getUserById').withArgs('userId').returns(null)
            user = @_builder._getUserInfoById('userId', true)
            test.deepEqual(user, {name: '(unknown)', email: '(unknown)'})
            test.done()

        testGetUserInfoById: sinon.test (test) ->
            sinon.stub(@_builder, '_getUserById').withArgs('userId').returns(
                name: 'name'
                email: 'email'
                avatar: 'avatar'
            )
            user = @_builder._getUserInfoById('userId', true)
            test.deepEqual(user,
                name: 'name',
                email: 'email',
                avatar: 'avatar'
            )
            test.done()
    
        testGetWaveTitleIfNoRootBlipFound: sinon.test (test) ->
            sinon.stub(@_builder, '_getBlipById').withArgs('blipId').returns(null)
            @_builder._wave = {rootBlipId: 'blipId'}
            title = @_builder._getWaveTitle()
            test.equal(title, null)
            test.done()
            
        testGetRootNodeIfNoContainerBlip: sinon.test (test) ->
            sinon.stub(@_builder, '_getWaveUrl').returns('')
            sinon.stub(@_builder, '_getWaveTitle').returns('')
            sinon.stub(@_builder, '_getContainerBlip').returns(null)
            root = @_builder._getRootNode()
            test.equal(root.nodes.length, 0)
            test.done()
                
        testInjectReplyIfNoBlipFound: sinon.test (test) ->
            sinon.stub(@_builder, '_getBlipById').withArgs('blipId').returns(null)
            @_builder._injectReply({id: 'blipId'})
            test.done()
