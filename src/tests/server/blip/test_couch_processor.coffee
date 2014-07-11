testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
CouchBlipProcessor = require('../../../server/blip/couch_processor').CouchBlipProcessor

module.exports =
    CouchBlipProcessorTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetByWaveIds: (test) ->
            waveIds = [1,2]
            viewParams = {
                keys: waveIds
            }            
            CouchBlipProcessorMock = sinon.mock(CouchBlipProcessor)
            CouchBlipProcessorMock
                .expects('viewWithIncludeDocs')
                .withArgs('blip/blips_by_wave_id', viewParams)
                .once()
                .callsArgWith(2, null, 'bmodels')

            CouchBlipProcessor.getByWaveIds(waveIds, (err, models) ->
                test.deepEqual('bmodels', models)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getChildTreeIds: (test) ->
            code = (done, exp, blipId, waveVertexes) ->
                res = CouchBlipProcessor._getChildTreeIds(blipId, waveVertexes)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                [['b1','b2','b3'],  'b1', {'b1':['b2'], 'b2': ['b3']}]
                [['b1','b2','b3'],  'b1', {'b1':['b2', 'b3']}]
                [['b2'],            'b2', {'b1':['b2', 'b3'], 'b2': []}]
                [['b1','b2'],       'b1', {'b1': ['b2'], 'b2': ['b1']}]
                [['b1'],            'b1', {}]
                [['b1'],            'b1', {'b1': ['b1']}]
                [['b1'],            'b1', {'b2': ['b45']}]
                [['b2','b1','b3'],  'b2', {'b1': ['b3', 'b2'], 'b2': ['b1']}]
            ], code)