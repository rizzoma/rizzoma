testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
CouchProcessor = require('../../../../server/common/db/couch_processor').CouchProcessor
Model = require('../../../../server/common/model').Model
DbError = require('../../../../server/common/db/exceptions').DbError
dataprovider = require('dataprovider')
Conf = require('../../../../server/conf').Conf

module.exports =
    CouchProcessorTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetByIdsAsDict: (test) ->
            ids = "ids"
            docs = "docs"
            models = "models"
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('_getWithCache')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, docs)
            processorMock
                .expects('_convertDocsToModels')
                .withArgs(docs)
                .once()
                .returns(models)
            processor.getByIdsAsDict(ids, (err, res) ->
                test.equal(models, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
            
        testGetByIds: (test) ->
            ids = ["key"]
            docs = {'key': 'value'}
            models = ['value']
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('getByIdsAsDict')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, docs)
            processor.getByIds(ids, (err, res) ->
                test.deepEqual(models, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testGetById: (test) ->
            id = "id"
            models = ['value']
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('getByIds')
                .withArgs([id])
                .once()
                .callsArgWith(1, null, models)
            processor.getById(id, (err, res) ->
                test.deepEqual(models[0], res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
        
        testGetByIdReturnErrNotFound: (test) ->
            id = "id"
            models = []
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('getByIds')
                .withArgs([id])
                .once()
                .callsArgWith(1, null, models)
            processor.getById(id, (err, res) ->
                test.deepEqual("not_found", err.message)
                test.deepEqual(null, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
            
        testViewWithIncludeDocsAsDict: (test) ->
            viewName = "some/view"
            viewParms = {}
            viewDocs = [{id: 'id'}]
            docs = "docs"
            models = "models"
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('view')
                .withArgs(viewName, viewParms)
                .once()
                .callsArgWith(2, null, viewDocs)
            processorMock
                .expects('_getWithCache')
                .withArgs(['id'])
                .once()
                .callsArgWith(1, null, docs)
            processorMock
                .expects('_convertDocsToModels')
                .withArgs(docs)
                .once()
                .returns(models)
            processor.viewWithIncludeDocsAsDict(viewName, viewParms, (err, res) ->
                test.equal(viewParms.include_docs, false)
                test.deepEqual(models, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
        
        testViewWithIncludeDocs: (test) ->
            viewName = "some/view"
            viewParms = {}
            models = {"modelKey": "modelValue"}
            processor = new CouchProcessor()
            processorMock = sinon.mock(processor)
            processorMock
                .expects('viewWithIncludeDocsAsDict')
                .withArgs(viewName, viewParms)
                .once()
                .callsArgWith(2, null, models)
            processor.viewWithIncludeDocs(viewName, viewParms, (err, res) ->
                test.deepEqual(['modelValue'], res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
        
        testGetOne: (test) ->
            code= (done, expErr, expRes, models) ->
                viewName = "some/view"
                viewParms = {}
                processor = new CouchProcessor()
                processorMock = sinon.mock(processor)
                processorMock
                    .expects('viewWithIncludeDocsAsDict')
                    .withArgs(viewName, viewParms)
                    .once()
                    .callsArgWith(2, null, models)
                processor.getOne(viewName, viewParms, (err, res) ->
                    if expErr
                        test.deepEqual(expErr, err.message)
                    test.deepEqual(expRes, res)
                    sinon.verifyAll()
                    sinon.restoreAll()
                    done()
                )
            dataprovider(test, [
                [null, 'model', {'modelKey': 'model'}]
                ['not_found', null, {}]
                ["Wrong view 'some/view' result count: 2", null, {'modelKey': 'model', 'model2Key': 'model2'}]
            ], code)

        testViewCallsDbViewAndReturnDbError: (test) ->
            viewName = "some/view"
            viewParms = {}
            docs = "docs"
            err = { error: "not_found" }
            processor = new CouchProcessor()
            dbMock = sinon.mock(processor._db)
            dbMock
                .expects('view')
                .withArgs(viewName, viewParms)
                .once()
                .callsArgWith(2, err, null)
            processor.viewWithIncludeDocs(viewName, viewParms, (err, res) ->
                test.ok(err instanceof DbError)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testSave: (test) ->
            couchProcessor = new CouchProcessor()
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('bulkSave')
                .withArgs(['bmodel'])
                .once()
                .callsArgWith(1, null, {d1: {'rev': 'revision'}})
        
            couchProcessor.save('bmodel', (err, res)->
                test.deepEqual('revision', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testSaveResolvingConflictsOk: (test) ->
            model = {}
            action = () ->
            actionArgs = []
            expectedRev = 'abc'
            callback = (err, rev) ->
                test.equal(null, err)
                test.equal(expectedRev, rev)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            couchProcessor = new CouchProcessor()
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('_parseArgs')
                .withArgs([model, action, actionArgs, callback])
                .once()
                .returns([model, action, actionArgs, callback])
            CouchProcessorMock
                .expects('_bulkSaveResolvingConflicts')
                .withArgs([model], action, actionArgs)
                .once()
                .callsArgWith(3, null, {'x': {error: null, rev: expectedRev}})
            couchProcessor.saveResolvingConflicts(model, action, actionArgs, callback)
        
        testSaveResolvingConflictsCallsReSaveResolvingConflicts: (test) ->
            model = new Model()
            model.id = 'bmodel'
            couchProcessor = new CouchProcessor()
            action = () ->
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('_saveResolvingConflicts')
                .withArgs(model, action)
                .once()
                .callsArgWith(3, {error: 'conflict'})

            CouchProcessorMock
                .expects('_reSaveResolvingConflicts')
                .withArgs(model.id, action)
                .once()
            couchProcessor.saveResolvingConflicts(model, action, (err) ->)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testReSaveResolvingConflicts: (test) ->
            model = new Model()
            model.id = 'bmodel'
            couchProcessor = new CouchProcessor()
            action = (model, actionArgs, callback) ->
            dBMock = sinon.mock(couchProcessor._db)
            dBMock
                .expects('get')
                .withArgs(model.id)
                .once()
                .callsArgWith(1, null, 'bdoc')
            converter = {toModel: (doc) ->}
            couchProcessor.converter = converter
            converterMock = sinon.mock(converter)
            converterMock
                .expects('toModel')
                .withArgs('bdoc')
                .once()
                .returns(model)
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('_saveResolvingConflicts')
                .withArgs(model, action)
                .once()
                .callsArgWith(3, null)

            couchProcessor._reSaveResolvingConflicts(model.id, action, null, (err) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_saveResolvingConflicts: (test) ->
            model = new Model()
            model.id = 'bmodel'
            couchProcessor = new CouchProcessor()

            action = (model, callback) ->
                callback(null, true, model, false)
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('save')
                .withArgs(model)
                .once()
                .callsArgWith(1, null)
            couchProcessor._saveResolvingConflicts(model, action, null, (err, res) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_saveResolvingConflictsIfargsArray: (test) ->
            model = new Model()
            model.id = 'bmodel'
            couchProcessor = new CouchProcessor()
            action = (model, actionArg, callback) ->
                callback(null, true, model, false)
            CouchProcessorMock = sinon.mock(couchProcessor)
            CouchProcessorMock
                .expects('save')
                .withArgs(model)
                .once()
                .callsArgWith(1, null)

            couchProcessor._saveResolvingConflicts(model, action, ['arg'], (err) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_parseArgs: (test) ->
            code = (done, exp, args) ->
                couchProcessor = new CouchProcessor()
                test.deepEqual(exp, couchProcessor._parseArgs(args))
                done()
            model = new Model()
            model.id = 'bmodel'
            action = () ->
            callback = () ->
            dataprovider(test, [
                [false, ['bmodel']],
                [false, [model, null]],
                [false, [model, action, null, null]],
                [[model, action, [], callback], [model, action, callback]],
            ], code)

        testBulkSaveIfLengthGreater1AndNotChanged: (test) ->
            doc1 = {_id: "doc1"}
            doc2 = {_id: "doc2"}
            docs = [doc1, doc2]
            revs = {'doc1': {id: 'doc1', 'rev': 'revision1'}, 'doc2': {id: 'doc2', 'rev': 'revision2'}}
            model1 = "model1"
            model2 = "model2"
            models = [model1, model2]
            couchProcessor = new CouchProcessor()
            converter = {toCouch: (model) ->}
            couchProcessor.converter = converter
            converterMock = sinon.mock(converter)
            converterMock
                .expects('toCouch')
                .withArgs(model1)
                .once()
                .returns(doc1)
            converterMock
                .expects('toCouch')
                .withArgs(model2)
                .once()
                .returns(doc2)
            dbMock = sinon.mock(couchProcessor._db)
            dbMock
                .expects('save')
                .withArgs(docs)
                .once()
                .callsArgWith(1, null, [{id:'doc1', 'rev': 'revision1'}, {id:'doc2', 'rev': 'revision2'}])
            Indexer = require('../../../../server/search/indexer').Indexer
            IndexerMock = sinon.mock(Indexer)
            IndexerMock
                .expects('makeIndexSource')
                .never()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_queueAddToCache')
                .withArgs(docs)
                .once()
                .callsArgWith(1, null)
            couchProcessor.bulkSave(models, (err, res) ->
                test.deepEqual({'doc1': {id: 'doc1', 'rev': 'revision1'}, 'doc2': {id: 'doc2', 'rev': 'revision2'}}, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testBulkSaveIfLengthEqual1AndNotChanged: (test) ->
            doc1 =
                _id: "d1"
            model1 = "model1"
            models = [model1]
            revs = {'d1': {id: 'd1', 'rev': 'revision1'}}
            toCache = { d1: { _id: 'd1', _rev: 'revision1' }}
            couchProcessor = new CouchProcessor()
            converter = {toCouch: (model) ->}
            couchProcessor.converter = converter
            converterMock = sinon.mock(converter)
            converterMock
                .expects('toCouch')
                .withArgs(model1)
                .once()
                .returns(doc1)
            dbMock = sinon.mock(couchProcessor._db)
            dbMock
                .expects('save')
                .withArgs(doc1)
                .once()
                .callsArgWith(1, null, {'rev': 'revision1'})
            Indexer = require('../../../../server/search/indexer').Indexer
            IndexerMock = sinon.mock(Indexer)
            IndexerMock
                .expects('makeIndexSource')
                .never()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_addToCache')
                .withArgs(toCache)
                .once()
                .callsArgWith(1, null, revs)
            couchProcessor.bulkSave(models, (err, res) ->
                test.deepEqual({ d1: { rev: 'revision1', id: 'd1' } }, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testBulkSaveIfLengthEqual1AndChanged: (test) ->
            doc1 =
                _id: "d1"
            model1 = "model1"
            models = [model1]
            revs = {'d1': {id: 'd1', 'rev': 'revision1'}}
            toCache = { d1: { _id: 'd1', _rev: 'revision1' }}
            couchProcessor = new CouchProcessor()
            converter = {toCouch: (model) ->}
            couchProcessor.converter = converter
            converterMock = sinon.mock(converter)
            converterMock
                .expects('toCouch')
                .withArgs(model1)
                .once()
                .returns(doc1)
            dbMock = sinon.mock(couchProcessor._db)
            dbMock
                .expects('save')
                .withArgs(doc1)
                .once()
                .callsArgWith(1, null, {'rev': 'revision1'})
            Indexer = require('../../../../server/search/indexer').Indexer
            IndexerMock = sinon.mock(Indexer)
            IndexerMock
                .expects('makeIndexSource')
                .once()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_addToCache')
                .withArgs(toCache)
                .once()
                .callsArgWith(1, null, revs)
            couchProcessor.bulkSave(models, (err, res) ->
                test.deepEqual({ d1: { rev: 'revision1', id: 'd1' } }, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getWithCacheLoadFromCacheAndDb: (test) ->
            ids = ['d1', 'd2', 'd3']
            dbDocs =
                'd1': 'doc1'
            cachedDocs =
                'd2': 'doc2'
                'd3': 'doc3'
            couchProcessor = new CouchProcessor()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_getFromCache')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, cachedDocs)
            couchProcessorMock
                .expects('_get')
                .withArgs(['d1'])
                .once()
                .callsArgWith(1, null, dbDocs)
            couchProcessorMock
                .expects('_addToCache')
                .withArgs(dbDocs)
                .once()
                .callsArgWith(1, null)

            couchProcessor._getWithCache(ids, (err, res) ->
                test.deepEqual({'d1': 'doc1', 'd2': 'doc2', 'd3': 'doc3'}, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getWithCacheLoadFromCacheOnly: (test) ->
            ids = ['d1', 'd2', 'd3']
            dbDocs = {}
            cachedDocs =
                'd1': 'doc1'
                'd2': 'doc2'
                'd3': 'doc3'
            couchProcessor = new CouchProcessor()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_getFromCache')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, cachedDocs)
            couchProcessorMock
                .expects('_get')
                .never()
            couchProcessorMock
                .expects('_addToCache')
                .never()
            couchProcessor._getWithCache(ids, (err, res) ->
                test.deepEqual({'d1': 'doc1', 'd2': 'doc2', 'd3': 'doc3'}, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getWithCacheLoadFromDbOnly: (test) ->
            ids = ['d1', 'd2', 'd3']
            dbDocs =
                'd1': 'doc1'
                'd2': 'doc2'
                'd3': 'doc3'
            cachedDocs = {}
            couchProcessor = new CouchProcessor()
            couchProcessorMock = sinon.mock(couchProcessor)
            couchProcessorMock
                .expects('_getFromCache')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, cachedDocs)
            couchProcessorMock
                .expects('_get')
                .withArgs(ids)
                .once()
                .callsArgWith(1, null, dbDocs)
            couchProcessorMock
                .expects('_addToCache')
                .withArgs(dbDocs)
                .once()
                .callsArgWith(1, null)

            couchProcessor._getWithCache(ids, (err, res) ->
                test.deepEqual({'d1': 'doc1', 'd2': 'doc2', 'd3': 'doc3'}, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_get: (test) ->
            code = (done, errExp, resExp, ids, err, docs) ->
                couchProcessor = new CouchProcessor()
                dbMock = sinon.mock(couchProcessor._db)
                dbMock
                    .expects('get')
                    .once()
                    .callsArgWith(1, err, docs)
                couchProcessor._get(ids, (err, res) ->
                    test.deepEqual(errExp, err)
                    test.deepEqual(resExp, res)
                    sinon.verifyAll()
                    sinon.restoreAll()
                    done()
                )
            md = (id) -> {doc: {_id: id}} # make document
            mr = (args...) ->
                # make result
                res = {}
                res[id] = {_id: id} for id in args
                return res

            dataprovider(test, [
                [null, mr('d1'), ['d1'], null, [md('d1')]]
                [
                    null,
                    mr('d2', 'd3'),
                    ['d2', 'd3'],
                    null,
                    [md('d2'), md('d3')]
                ]
                [null, {}, ['d4'], { error: 'not_found'}, null]
                [null, {}, ['d5'], { error: 'xz error'}, null]
                [
                    null,
                    mr('d6', 'd8'),
                    ['d6', 'd7', 'd8'],
                    null,
                    [md('d6'), {key: 'd7', error:{ error: 'xz error'}}, md('d8') ]
                ]
            ], code)

        test_convertDocsToModels: (test) ->
            docs =
                'd1':'doc1',
                'd2':'doc2'
            couchProcessor = new CouchProcessor()
            converter = {toModel: (doc) ->}
            couchProcessor.converter = converter
            converterMock = sinon.mock(converter)
            converterMock
                .expects('toModel')
                .withArgs('doc1')
                .once()
                .returns('model1')
            converterMock
                .expects('toModel')
                .withArgs('doc2')
                .once()
                .returns('model2')
            res = couchProcessor._convertDocsToModels(docs)
            test.deepEqual({'d1': 'model1', 'd2': 'model2'}, res)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        ###
        testIntegrate: (test) ->
            couchProcessor = new CouchProcessor()
            ids = ['0_w_1', '0_w_99']
            params =
                key: '0_w_1'
            couchProcessor._db.view('blip/blips_by_wave_id', params, (err, res) ->
                console.log(res)
            )
        ###
