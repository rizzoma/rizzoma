sinon = require('sinon')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
WaveModel = require('../../../server/wave/models').WaveModel
Ptag = require('../../../server/ptag').Ptag

ALL_PTAG_ID = Ptag.ALL_PTAG_ID
FOLLOW_PTAG_ID = Ptag.FOLLOW_PTAG_ID
UNFOLLOW_PTAG_ID = Ptag.UNFOLLOW_PTAG_ID
WAVE_ROLE_MODERATOR = require('../../../server/wave/constants').WAVE_ROLE_MODERATOR

getModel = () ->
    model = new WaveModel()
    model.participants = [
       {
           "id": "1",
           "role": "foo",
           "ptags": [
               0,
               255
           ]
       },
       {
           "id": "2",
           "ptags": [
               0,
               255
           ]
       },
       {
           "id": "3",
           "role": "foo",
           "ptags": [
               0,
               254
           ]
       }
    ]
    return model

module.exports =
    WaveModelTest: testCase
        setUp: (callback) ->
            @_model = getModel()
            callback()

        testGetParticipantsWithRole: (test) ->
            res = @_model.getParticipantsWithRole()
            test.deepEqual(res, [
               {
                   "id": "1",
                   "role": "foo",
                   "ptags": [
                       0,
                       255
                   ]
               },
               {
                   "id": "3",
                   "role": "foo",
                   "ptags": [
                       0,
                       254
                   ]
               }            
            ])
            test.done()

        testGetFirstParticipantWithRole: (test) ->
            res = @_model.getFirstParticipantWithRole()
            test.deepEqual(res, {"id": "1", "role": "foo", "ptags": [0, 255]})
            test.done()

        testGetFirstParticipantWithRoleReturnsNull: (test) ->
            @_model.participants = [{id: 1}, {id: 2}]
            res = @_model.getFirstParticipantWithRole()
            test.equal(res, null)
            test.done()

        testHasParticipantWithRole: (test) ->
            testCode = (done, id, expected) =>
                res = @_model.hasParticipantWithRole(id)
                test.equal(res, expected)
                done()
            dataprovider(test, [['1', true], ['2', false]], testCode)

        testUpdateUrls: (test) ->
            @_model.updateUrls()
            test.equals(@_model.urls.length, 2)
            test.done()

        testGetParticipantByIndex: (test) ->
            res = @_model.getParticipantByIndex(1)
            test.deepEqual(res, {"id": "2", "ptags": [0, 255]})
            test.done()

        testGetParticipantIndex: (test) ->
            testCode = (done, id, consideringRole, expected) =>
                res = @_model.getParticipantIndex(id, consideringRole)
                test.equal(res, expected)
                done()
            dataprovider(test, [['3', false, 2], ['3', true, 1], ['4', false, null], ['4', true, null]], testCode)

        testGetParticipant: (test) ->
            testCode = (done, id, expected) =>
                res = @_model.getParticipant(id)
                test.deepEqual(res, expected)
                done()
            dataprovider(test, [['3', {id: '3', role: 'foo', ptags: [0, 254]}], ['4', null]], testCode)           

        testHasParticipant: (test) ->
            testCode = (done, id, expected) =>
                res = @_model.hasParticipant(id)
                test.equal(res, expected)
                done()
            dataprovider(test, [['2', true], ['5', false]], testCode)

        testGetParticipantRole: (test) ->
            testCode = (done, id, expected) =>
                res = @_model.getParticipantRole(id)
                test.equal(res, expected)
                done()
            dataprovider(test, [['1', 'foo'], ['2', undefined], ['5', null]], testCode)

        testGetParticipantRole: (test) ->
            @_model.participants[0].role = WAVE_ROLE_MODERATOR
            testCode = (done, id, expected) =>
                res = @_model.hasAnotherModerator(id)
                test.equal(res, expected)
                done()
            dataprovider(test, [['1', false], ['2', true]], testCode)

        testGetUrl: (test) ->
            @_model.urls.push('foo')
            res = @_model.getUrl()
            test.equal(res, 'foo')
            test.equal(@_model.urls.length, 2)
            test.done()

        getParticipantPtags: (test) ->
            testCode = (done, id, expected) =>
                res = @_model.getParticipantPtags(id)
                test.deepEqual(res, expected)
                done()
            dataprovider(test, [['3', [0, 254]], ['5', null]], testCode)       

        testSetParticipantFollowState: (test) ->
            testCode = (done, id, state, index, ptags, expected) ->
                model = getModel()
                res = model.setParticipantFollowState(id, state)
                test.deepEqual(model.participants[index].ptags, ptags)
                test.equal(res, expected)
                done()
            dataprovider(test, [
                ['1', false, 0, [ALL_PTAG_ID, UNFOLLOW_PTAG_ID], true]
                ['1', true, 0, [ALL_PTAG_ID, FOLLOW_PTAG_ID], undefined]
                ['3', false, 2, [ALL_PTAG_ID, UNFOLLOW_PTAG_ID], undefined]
                ['3', true, 2, [ALL_PTAG_ID, FOLLOW_PTAG_ID], true]
            ], testCode) 

