testCase = require('nodeunit').testCase
Migration = require('../../../../server/common/migration').Migration

module.exports =
    CouchConverterTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testRolledPatches: (test) ->
            doc =
                _id: 'some_id'
                format: 0
            # Патчи для документа.
            Migration._migrationFunctions = [
                (doc) ->
                    doc.foo1 = 'bar1'
                    doc.format += 1
                    return doc
                (doc) ->
                    doc.foo2 = 'bar2'
                    doc.format += 1
                    return doc
            ]
            doc = Migration.migrateFormat(doc) # Накатываем патчи
            actualFormat = Migration.actualFormat() # Версия формата или кол-во патчей

            test.equal(actualFormat, 2)
            test.equal(doc.format, 2)
            test.equal(doc.foo1, 'bar1')
            test.equal(doc.foo2, 'bar2')
            test.equal(doc._id, 'some_id')
            test.done()
