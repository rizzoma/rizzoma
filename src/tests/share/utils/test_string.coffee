sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
StringUtils = require('../../../share/utils/string')
dataprovider = require('dataprovider')

module.exports =
    matchUrlsTest: testCase
        setUp: (callback) ->
            callback()

        matchUrls0: (test) ->
            test.deepEqual([], StringUtils.matchUrls(''))
            test.done()

        matchUrls1: (test) ->
            test.deepEqual([], StringUtils.matchUrls('http:'))
            test.done()

        matchUrls2: (test) ->
            test.deepEqual([], StringUtils.matchUrls('http://'))
            test.done()

        matchUrls3: (test) ->
            test.deepEqual([], StringUtils.matchUrls('http:// '))
            test.done()

        matchUrls4: (test) ->
            test.deepEqual([], StringUtils.matchUrls(' http:// '))
            test.done()

        matchUrls5: (test) ->
            test.deepEqual([{startIndex: 0, endIndex: 11}], StringUtils.matchUrls('http://cdev'))
            test.done()

        matchUrls6: (test) ->
            test.deepEqual([], StringUtils.matchUrls('http://1'))
            test.done()

        matchUrls7: (test) ->
            test.deepEqual([{startIndex: 0, endIndex: 9}], StringUtils.matchUrls('http://12'))
            test.done()

        matchUrls8: (test) ->
            test.deepEqual([{startIndex: 3, endIndex: 14}], StringUtils.matchUrls('   http://cdev, test'))
            test.done()

        matchUrls9: (test) ->
            res = [
                {startIndex: 0, endIndex: 35}
                {startIndex: 36, endIndex: 74}
            ]
            test.deepEqual(res, StringUtils.matchUrls('tel:+7777,http://ya.ru;https://g.ru mailto:test@ex.com!http://rz.com/topic,'))
            test.done()

        matchUrls10: (test) ->
            res = [
                {startIndex: 0, endIndex: 9}
                {startIndex: 11, endIndex: 23}
                {startIndex: 25, endIndex: 37}
                {startIndex: 38, endIndex: 56}
                {startIndex: 63, endIndex: 83}
            ]
            test.deepEqual(res, StringUtils.matchUrls('tel:+7777, http://ya.ru;\nhttps://g.ru\nmailto:test@ex.com, site-http://rz.com/topic/'))
            test.done()

        matchUrls11: (test) ->
            res = [
                {startIndex: 0, endIndex: 9}
                {startIndex: 11, endIndex: 23}
                {startIndex: 25, endIndex: 37}
                {startIndex: 38, endIndex: 56}
                {startIndex: 63, endIndex: 83}
            ]
            test.deepEqual(res, StringUtils.matchUrls('tel:+7777, http://ya.ru;\nhttps://g.ru\nmailto:test@ex.com, site-http://rz.com/topic/\n'))
            test.done()

        matchUrls12: (test) ->
            res = [
                {startIndex: 0, endIndex: 9}
                {startIndex: 11, endIndex: 23}
                {startIndex: 25, endIndex: 37}
                {startIndex: 38, endIndex: 56}
                {startIndex: 63, endIndex: 90}
            ]
            test.deepEqual(res, StringUtils.matchUrls('tel:+7777, http://ya.ru;\nhttps://g.ru\nmailto:test@ex.com, site-mailto:http://rz.com/topic/\n'))
            test.done()

        matchUrls13: (test) ->
            res = [
                {startIndex: 0, endIndex: 9}
                {startIndex: 11, endIndex: 23}
                {startIndex: 25, endIndex: 37}
                {startIndex: 38, endIndex: 56}
                {startIndex: 67, endIndex: 87}
            ]
            test.deepEqual(res, StringUtils.matchUrls('tel:+7777, http://ya.ru;\nhttps://g.ru\nmailto:test@ex.com, site-ftp:http://rz.com/topic/\n'))
            test.done()

        matchUrls14: (test) ->
            res = [
                {startIndex: 0, endIndex: 18}
                {startIndex: 25, endIndex: 51}
            ]
            test.deepEqual(res, StringUtils.matchUrls('mailto:test@ex.com,\tsite-ftp://http://rz.com/topic/'))
            test.done()

        matchUrls15: (test) ->
            res = [
                {startIndex: 0, endIndex: 18}
                {startIndex: 30, endIndex: 50}
            ]
            test.deepEqual(res, StringUtils.matchUrls('mailto:test@ex.com,\tsiteftp://http://rz.com/topic/'))
            test.done()

        matchUrls16: (test) ->
            res = [
                {startIndex: 0, endIndex: 18}
                {startIndex: 32, endIndex: 57}
            ]
            test.deepEqual(res, StringUtils.matchUrls('mailto:test@ex.com,\tsite:1ftp://HTTP://RIZZOMA.com/topic/'))
            test.done()

        matchUrls17: (test) ->
            test.deepEqual([], StringUtils.matchUrls('asdfhttp://rizzoma.com/asdfasdf/sfdgsdfgaasdfasdf,safda//\\#$ asdf'))
            test.done()

        matchUrls18: (test) ->
            res = [
                {startIndex: 66, endIndex: 78}
            ]
            test.deepEqual(res, StringUtils.matchUrls('asdfhttp://rizzoma.com/asdfasdf/sfdgsdfgaasdfasdf,safda//\\#$ asdf http://ya.ru'))
            test.done()

        matchUrls19: (test) ->
            res = [
                {startIndex: 0, endIndex: 12}
                {startIndex: 81, endIndex: 93}
            ]
            test.deepEqual(res, StringUtils.matchUrls('http://ya.ru 1mailto:rizzoma.com/asdfasdf/sfdgsdfgaasdfasdf,safda//\\#$ asdf asdf http://ya.ru'))
            test.done()

        matchUrls20: (test) ->
            res = [
                {startIndex: 0, endIndex: 14}
                {startIndex: 17, endIndex: 73}
                {startIndex: 84, endIndex: 96}
            ]
            test.deepEqual(res, StringUtils.matchUrls('http://mail.ru 1 mailto:rizzoma.com/asdfasdf/sfdgsdfgaasdfasdf,safda//\\#$ asdf asdf http://ya.ru'))
            test.done()

        matchUrls21: (test) ->
            res = [
                {startIndex: 3, endIndex: 70}
            ]
            test.deepEqual(res, StringUtils.matchUrls('12\\http://mail.ru?a=1,b[0]=asdf&b[0]=asdf&test=%20%25!aaaa#test?789#10\nwww.google.com'))
            test.done()
