global.getLogger = () ->
    return {error: ->}
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
Digest = require('../../../server/changes_digest').ChangesDigestNotificator
digest = new Digest()
digest.DIGEST_PERIOD = 60 * 60 * 24
digest._now = 60 * 60 * 24 * 365 * 3000

module.exports =
    TestNotificator: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        test_getUserChangesMinTimestamp: (test) ->
            code = (done, exp, lastDigestSent) ->
                res = digest._getUserChangesMinTimestamp({lastDigestSent})
                test.equals(exp, res)
                done()
            dataprovider(test, [
                [60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24 - 60 * 60 * 6, null]
                [60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24, 60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24]
                [60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24 - 1, 60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24 - 1]
                [60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24 - 60 * 60 * 6, 60 * 60 * 24 * 365 * 3000 - 60 * 60 * 24 - 60 * 60 * 7]
            ], code)