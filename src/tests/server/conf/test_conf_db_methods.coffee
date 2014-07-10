###
Тестируем методы работы с настройками БД в классе Conf.
###
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')

conf = require('../../../server/conf/conf')

_getConf = () ->
    dbconf =
        type: 'cradle'
        protocol: 'http'
        hostname: '127.0.0.1'
        port: 5984
        options:
            cache: false
            #auth:
            #    username: 'root'
            #    password: 'secret'
        db: 'db_name'
    return dbconf

module.exports =
    ConfDbTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetDbConf: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
                .expects('_initLogger')
                .once()
            c = new conf({db: {test: _getConf()}})
            test.deepEqual c.getDbConf('test'), _getConf()
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testGetDbConfUnknown: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({db: {test: _getConf()}})
            test.throws( -> c.getDbConf('test2'))
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

    ConfCradleDbTest: testCase
        testGetDbUrl: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({db: {test: _getConf()}})
            test.equal c.getDbUrl('test'), 'http://127.0.0.1:5984/db_name'
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetDbUrlWithAuth: (test) ->
            dbconf = _getConf()
            dbconf.options.auth =
                username: 'user'
                password: 'pwd-'
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({db: {test: dbconf}})
            test.equal c.getDbUrl('test'), 'http://user:pwd-@127.0.0.1:5984/db_name'
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testGetDbUrlWithUnknownType: (test) ->
            dbconf = _getConf()
            dbconf.type = 'not cradle'
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({db: {test: dbconf}})
            test.throws( -> c.getDbUrl('test'))
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

    ConfSessionTest: testCase
        testGetSessionConfValuesCopied: (test) ->
            exp = {secret: 'a', key: 'b'}
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: exp})
            actual = c.getSessionConf()
            test.equal actual.secret, exp.secret
            test.equal actual.key, exp.key
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetSessionConfReturnsSameStoreInstance: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: {}})
            actual1 = c.getSessionConf()
            actual2 = c.getSessionConf()
            test.strictEqual actual1, actual2
            test.strictEqual actual1.store, actual2.store
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetSessionConfDefaultKey: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: {}})
            actual = c.getSessionConf().key
            test.ok actual && actual.length>0
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
            
        testGetSessionConfDefaultStoreType: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: {}})
            test.equal c.getSessionConf().storeType, 'memory'
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetSessionConfMemoryStore: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: {storeType: 'memory'}})
            actual = c.getSessionConf()
            test.equal actual.storeType, 'memory'
            test.ok(actual.store instanceof require('express').session.MemoryStore)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetSessionConfRedisStore: (test) ->
            redis_mock = 
                select: (db) ->
                    test.equal db, 1
                on: () ->
            
            session_conf = 
                storeType: 'redis'
                storeOptions:
                    client: redis_mock
                    db: 1
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: session_conf})
            actual = c.getSessionConf()
            test.equal actual.storeType, 'redis'
            test.expect(2)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
        
        testGetSessionConfUnknownStore: (test) ->
            ConfMock = sinon.mock(conf.prototype)
            ConfMock
            .expects('_initLogger')
            .once()
            c = new conf({session: {storeType: 'zzz'}})
            test.throws( -> c.getSessionConf())
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

