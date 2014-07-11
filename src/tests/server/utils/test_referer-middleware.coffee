sinon = require('sinon-plus')
async = require('async')
testCase = require('nodeunit').testCase
refererMiddleware = require('../../../server/utils/middleware/referer-middleware')

TESTS = [{
          test:'148911669.1334139348.1.1.utmcsr=habra-habr.ru|utmccn=(referral)|utmcmd=referral|utmcct=/post/141312/'
          res:'habra-habr.ru/post/141312/'
         },
         {
          test:'utmcsr=148911669.1325asdasd00.1.1.utmcsr=148911669.1325085400.1.1.utmcsr=habrahabr.ru|utmccn=(referral)|utmcmd=referral|utmcct='
          res:'habrahabr.ru'
         },
         {
          test:'148911669.1334823003.4.4.utmcsr=habr|utmccn=saasreview|utmcmd=feed'
          res:'habr'
         },
         {
          test:'148911669.1334829135.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)'
          res:''
         }]

module.exports =
    TestParseGACookie: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testCookie: (test) ->
            for t in TESTS
                res = refererMiddleware.parseGACookie(t.test)
                test.equal(t.res, res)
            test.done()