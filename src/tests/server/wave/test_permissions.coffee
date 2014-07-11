sinon = require('sinon')
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
cts = require('../../../server/wave/constants')
User = require('../../../server/user/model').UserModel
Wave = require('../../../server/wave/models').WaveModel
WP = require('../../../server/wave/permissions')
WavePermissionsChecker = require('../../../server/wave/permissions').WavePermissionsChecker

module.exports =
    TestWavePermissionsChecker: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testAuthorizes: (test) ->
            testCode = (done, hasParticipant, waveParticipantRole, isLoggedIn, expected) ->
                user = new User()
                wave = new Wave()
                userMock = sinon.mock(user)
                waveMock = sinon.mock(wave)
                userMock
                    .expects('isAnonymous')
                    .once()
                    .returns(not isLoggedIn)
                if isLoggedIn
                    waveMock
                        .expects('hasParticipant')
                        .once()
                        .returns(hasParticipant)
                    waveMock
                        .expects('getParticipantRole')
                        .once()
                        .returns(waveParticipantRole)
                test.equal(expected, WavePermissionsChecker._authorize(user, wave))
                done()

            testCases = [
                [true, cts.WAVE_ROLE_MODERATOR, true, WP.ROLE_MODERATOR],
                [true, cts.WAVE_ROLE_READER, true, WP.ROLE_READER],
                [false, undefined, true, WP.ROLE_GUEST],
                [false, undefined, false, WP.ROLE_ANONYMOUS],
            ]
            dataprovider(test, testCases, testCode)

        testGetRolePermissions: (test) ->
            privateWave = {
                getSharedState: () ->
                    return cts.WAVE_SHARED_STATE_PRIVATE
            }
            publicWave = {
                getSharedState: () ->
                    return cts.WAVE_SHARED_STATE_PUBLIC
            }

            testCode = (done, role, wave, res) =>
                test.equal(res ,WavePermissionsChecker._getRolePermissions(role, wave))
                done()

            testCases = [
                # публичная волна
                [WP.ROLE_GUEST,
                    publicWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_GUEST][cts.WAVE_SHARED_STATE_PUBLIC]],
                [WP.ROLE_READER,
                    publicWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_READER][cts.WAVE_SHARED_STATE_PUBLIC]],
                [WP.ROLE_MODERATOR,
                    publicWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_MODERATOR][cts.WAVE_SHARED_STATE_PUBLIC]],
                [WP.ROLE_ANONYMOUS,
                    publicWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_ANONYMOUS][cts.WAVE_SHARED_STATE_PUBLIC]],

                # Приватная волна
                [WP.ROLE_GUEST,
                    privateWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_GUEST][cts.WAVE_SHARED_STATE_PRIVATE]],
                [WP.ROLE_READER,
                    privateWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_READER][cts.WAVE_SHARED_STATE_PRIVATE]],
                [WP.ROLE_MODERATOR,
                    privateWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_MODERATOR][cts.WAVE_SHARED_STATE_PRIVATE]],
                [WP.ROLE_ANONYMOUS,
                    privateWave,
                    WP.ROLE_PERMSSIONS[WP.ROLE_ANONYMOUS][cts.WAVE_SHARED_STATE_PRIVATE]],
            ]

            dataprovider(test, testCases, testCode)
