testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
BlipQueryBuilder = require('../../../server/blip/query_builder').BlipQueryBuilder
blipQueryBuilder = new BlipQueryBuilder()

module.exports =
    BlipQueryBuilderTest: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        test_getGTags: (test) ->
            code = (done, exp, queryString) ->
                res = blipQueryBuilder._getGTags(queryString)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                [[], ""]
                [[], "dfgvdf sdfgdf dfg"]
                [[], ")(*^%#"]
                [["#123", "#sdf"], " #123 #sdf dfgfdg trh"]
            ], code)

        test_getGTagsQueryString: (test) ->
            code = (done, exp, gtags) ->
                res = blipQueryBuilder._getGTagsQueryString(gtags)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                ["", []]
                ["@gtags =123", ["#123"]]
                ["@gtags =123 =dfgbdg", ["#123", "#dfgbdg"]]
            ], code)

        test_removeGTagsFromQueryString: (test) ->
            code = (done, exp, queryString, gtags) ->
                res = blipQueryBuilder._removeGTagsFromQueryString(queryString, gtags)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                #["", "", []]
                ["aaa", "#qwerty #xxx aaa", ["#qwerty", "#xxx"]]
                ["aaa", "#qwerty aaa #xxx", ["#qwerty", "#xxx"]]
                ["aaa bbb", " #qwerty aaa #xxx bbb ", ["#qwerty", "#xxx"]]
                ["\" aaa bbb\"", "\"#qwerty aaa #xxx bbb\"", ["#qwerty", "#xxx"]]
            ], code)
