sinon = require('sinon-plus')
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
User = require('../../../server/user/model').User
UserNotification = require('../../../server/user/model').UserNotification
Conf = require('../../../server/conf').Conf

module.exports =
    TestUser: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

#        testLoggedIn: (test) ->
#            testCode = (done, userId, res) =>
#                user = new User()
#                user.id = userId
#
#                test.equal(res, user.isLoggedIn())
#                done()
#
#            testCases = [
#                [null, false],
#                ['0_user_0', false], # Аноним
#                ['isRightUserId', true], # Аутентифицированный
#            ]
#
#            dataprovider(test, testCases, testCode)
#
#            test.done()

        testGetTransports: (test) ->
            code = (done, exp, state, confRules, userSettings, type) ->
                userNotification = new UserNotification()
                userNotification.state = state
                userNotification.setSettings(userSettings)
                confMock = sinon.mock(Conf)
                confMock
                    .expects('getNotificationConf')
                    .returns({rules: confRules})
                res = userNotification.getTransports(type)
                test.deepEqual(exp, res)
                sinon.verifyAll()
                sinon.restoreAll()
                done()

            dataprovider(test, [
                [[], 'deny-all', {}, {}, 'some_type']
                [[], 'deny-all', {'some_type': ['smtp']}, {}]
                [[], null, {}, null, 'some_type']
                [[], null, {}, {}, 'some_type']
                [[], null, {}, {'some_type': { 'smtp': true }}, 'some_type']
                [[], null, {'some_type': []}, {'some_type': { 'smtp': true }}, 'some_type']
                [['smtp'], null, {'some_type': ['smtp']}, {'some_type': { 'smtp': true }}, 'some_type']
                [['smtp', 'xmpp'], null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true }}, 'some_type']
                [['smtp'], null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true, 'xmpp': false }}, 'some_type']
                [['smtp'], null, {'some_type': ['smtp']}, {'some_type': { 'smtp': true, 'xmpp': true }}, 'some_type']
                [['smtp', 'xmpp'], null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true, 'xmpp': true }}, 'some_type']
                [['smtp', 'xmpp'], null, {'some_type': ['smtp', 'xmpp']}, {'some_type': {}}, 'some_type']
                [['smtp', 'xmpp'], null, {'some_type': ['smtp', 'xmpp']}, {}, 'some_type']
                [['smtp', 'xmpp'], null, {'some_type': ['smtp', 'xmpp']}, null, 'some_type']
            ], code)

        testGetSettings: (test) ->
            code = (done, exp, state, confRules, userSettings) ->
                userNotification = new UserNotification()
                userNotification.state = state
                userNotification.setSettings(userSettings)
                confMock = sinon.mock(Conf)
                confMock
                    .expects('getNotificationConf')
                    .returns({ rules: confRules })
                res = userNotification.getSettings()
                test.deepEqual(exp, res)
                sinon.verifyAll()
                sinon.restoreAll()
                done()

            dataprovider(test, [
                [{}, 'deny-all', {}, {}]
                [{'some_type': {'smtp': false }}, 'deny-all', {'some_type': ['smtp']}, {}]
                [{}, null, {}, null]
                [{}, null, {}, {}]
                [{}, null, {}, {'some_type': { 'smtp': true }}]
                [{'some_type': {}}, null, {'some_type': []}, {'some_type': { 'smtp': true }}]
                [{'some_type': { 'smtp': true }}, null, {'some_type': ['smtp']}, {'some_type': { 'smtp': true }}]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true }}]
                [{'some_type': { 'smtp': true, 'xmpp': false }}, null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true, xmpp: false }}]
                [{'some_type': { 'smtp': true}}, null, {'some_type': ['smtp']}, {'some_type': { 'smtp': true, 'xmpp': true }}]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, {'some_type': { 'smtp': true, 'xmpp': true }}]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, {'some_type': {}}]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, {}]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, null]
                [{'some_type': { 'smtp': true, 'xmpp': true }}, null, {'some_type': ['smtp', 'xmpp']}, null]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': true }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    null
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': true }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {}
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': true }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {
                        'daily_changes_digest': { 'smtp': true }
                        'weekly_changes_digest': { 'smtp': true }
                    }
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': true }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {
                        'daily_changes_digest': { 'smtp': true }
                    }
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': false }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': false }
                    }
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': true }
                        'weekly_changes_digest': { 'smtp': false }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {
                        'daily_changes_digest': { 'smtp': true }
                        'weekly_changes_digest': { 'smtp': false }
                    }
                ]
                [
                    {
                        'daily_changes_digest': { 'smtp': false }
                        'weekly_changes_digest': { 'smtp': false }
                    }
                    null
                    {
                        'daily_changes_digest': ['smtp'],
                        'weekly_changes_digest': ['smtp']
                    }
                    {
                        'weekly_changes_digest': { 'smtp': false }
                    }
                ]
                [{'new_comment': { 'smtp': false }}, null, {'new_comment': ['smtp']}, {}]
                [{'new_comment': { 'smtp': false }}, null, {'new_comment': ['smtp']}, {'new_comment': {}}]
                [{'new_comment': { 'smtp': false }}, null, {'new_comment': ['smtp']}, {'new_comment': { 'smtp': false }}]
                [{'new_comment': { 'smtp': true }}, null, {'new_comment': ['smtp']}, {'new_comment': { 'smtp': true }}]
            ], code)