testCase = require('nodeunit').testCase

isRobot = require('../../../server/utils/http_request').isRobot

module.exports =
    UtilsTest: testCase

        testIsRobotIfGoogHeader: (test) ->
            headers = {'x-goog-source': true}
            result = isRobot({headers})
            test.ok(result)
            test.done()

        testIsRobotIfGooglePlusUA: (test) ->
            headers = {'user-agent': 'Mozilla/5.0 (Windows NT 6.1; rv:6.0) Gecko/20110814 Firefox/6.0 Google (+https://developers.google.com/+/web/snippet/)'}
            result = isRobot({headers})
            test.ok(result)
            test.done()

        testIsRobotIfNoUserAgent: (test) ->
            headers = {}
            result = isRobot({headers})
            test.ok(not result)
            test.done()
            
        testIsRobotIfGooglebot: (test) ->
            headers = {'user-agent': 'Foo Googlebot Bar'}
            result = isRobot({headers})
            test.ok(result)
            test.done()
    
        testIsRobotIfNotRobot: (test) ->
            headers = {'user-agent': 'Foo Bar'}
            result = isRobot({headers})
            test.ok(not result)
            test.done()
