testCase = require('nodeunit').testCase
U = require('../../../server/user/utils').UserUtils

module.exports =
    TestUserUtils: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testIsGoogleEmail: (test) ->
          test.ok(U.isGoogleEmail('abc@gmail.com'))
          test.ok(U.isGoogleEmail('abc@googlemail.com'))
          test.ok(not U.isGoogleEmail('abc@yandex.ru'))
          test.ok(not U.isGoogleEmail('abc@gmail.com.domain.com'))
          test.done()

        testNormalizeGoogleEmail: (test) ->
          test.equal(U._normalizeGoogleEmail('abc@gmail.com'), 'abc@googlemail.com')
          test.equal(U._normalizeGoogleEmail('abc@googlemail.com'), 'abc@googlemail.com')
          test.equal(U._normalizeGoogleEmail('abc+d123@gmail.com'), 'abc@googlemail.com', 'Removes +part')
          test.equal(U._normalizeGoogleEmail('ab.c+d123@gmail.com'), 'abc@googlemail.com', 'Removes . from name')
          test.done()

        testNormalizeEmail: (test) ->
          test.equal(U.normalizeEmail(' UserName@Facebook.com  '), 'username@facebook.com', 'Trims and lower cases')
          test.equal(U.normalizeEmail('abc@gmail.com'), 'abc@googlemail.com', 'Uses _normalizeGoogleEmail')
          test.done()
