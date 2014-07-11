testCase = require('nodeunit').testCase
WaveModel = require('../../../server/wave/models').WaveModel
WaveCouchConverter = require('../../../server/wave/couch_converter').WaveCouchConverter

module.exports =
    TestWaveCouchConverter: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromModelToCouch: (test) ->
            model = new WaveModel()
            model.id = 1
            model._rev = 1
            model.participants = [1, 2]
            model.rootBlipId = 1
            model.timestamp = 'now'
            model.setSharedState('private')
            
            exp = {}
            exp._id = 1
            exp._rev = 1
            exp.type = 'wave'
            exp.participants = [1, 2]
            exp.rootBlipId = 1
            exp.timestamp = 'now'
            exp.version = 0
            exp.sharedState = 'private'
            
            doc = WaveCouchConverter.fromModelToCouch(model)
            test.deepEqual(exp, doc)
            test.done()
        
        testFromCouchToModel: (test) ->
            exp = new WaveModel()
            exp.id = 1
            exp._rev = 1
            exp.participants = [1, 2]
            exp.rootBlipId = 1
            exp.timestamp = 'now'
            exp.version = 0
            exp._type = 'wave'
            exp.setSharedState('private')
            
            doc = {}
            doc._id = 1
            doc._rev = 1
            doc.participants = [1, 2]
            doc.rootBlipId = 1
            doc.timestamp = 'now'
            doc.version = 0
            doc.sharedState = 'private'
            
            model = WaveCouchConverter.fromCouchToModel(doc)
            test.deepEqual(exp, model)
            test.done()
