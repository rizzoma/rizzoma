sinon = require('sinon')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
Ptag = require('../../../server/ptag').Ptag
UserModel = require('../../../server/user/model').UserModel

FOLLOW = Ptag.FOLLOW_PTAG_ID
ALL = Ptag.ALL_PTAG_ID

module.exports =
    PtagTest: testCase
        setUp: (callback) ->
            callback()

        testGetCommonPtagId: (test) ->
            testCode = (done, tagName, expected) ->
                res = Ptag.getCommonPtagId(tagName)
                test.equal(res, expected)
                done()
            dataprovider(test, [['FOLLOW', FOLLOW], ['ALL', ALL], ['FOO', ALL]], testCode)

        testGetSearchPtagId: (test) ->
            testCode = (done, user, ptagId, expected) ->
                res = Ptag.getSearchPtagId(user, ptagId)
                test.equal(res, expected)
                done()
            dataprovider(test, [
                ['foo', null, null]
                ['0_u_15', 0, 9472]
                ['0_u_15', 254, 9726]
                [new UserModel('0_u_15'), 0, 9472]
                [new UserModel('0_u_15'), 254, 9726]
            ], testCode)

        testParseSearchPtagId: (test) ->
            testCode = (done, id, expected) ->
                res = Ptag.parseSearchPtagId(id)
                test.deepEqual(res, expected)
                done()
            dataprovider(test, [
                [9726, ['0_u_15', 254]]
                ['9726', ['0_u_15', 254]]
                ['asdsd', [null, null]]
            ], testCode)
