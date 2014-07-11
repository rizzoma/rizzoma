async = require('async')
BlipProcessor = require('../blip/processor').BlipProcessor
WaveProcessor = require('./processor').WaveProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Notificator = require('../notification').Notificator
WaveError = require('./exceptions').WaveError
DbError = require('../common/db/exceptions').DbError

class WaveNotificator
    constructor: () ->

    sendInvite: (wave, user, participants, callback) ->
        ###
        Отправляет приглашение в топик добавленным участникам.
        @param wave: WaveModel
        @param user: UserModel
        @param participants: array of UserModel
        @param callback: function
        ###
        tasks = [
            async.apply(BlipProcessor.getBlip, wave.rootBlipId)
            (blip, callback) ->
                UserCouchProcessor.getById(user.id, (err, user) ->
                    callback(err, blip, user)
                )
            (blip, user, callback) ->
                notifications = []
                for participant in participants
                    context =
                        waveId: wave.getUrl()
                        user: user
                        waveTopic: blip.getTitle()
                        replyTo: user
                        from: user
                        referalEmailHash: wave.getParticipant(participant).getReferalEmailHash(wave.id)
                    notifications.push({user: participant, context: context})
                return callback(null) if not notifications.length
                Notificator.notificateUsers(notifications, "add_participant", callback)
        ]
        async.waterfall(tasks, callback)

    sendAccessRequest: (user, waveUrl, callback) ->
        ###
        Запрос на добавление участника в топик
        отправляет письмо автору топкиа с просьбой добавить туда нового участника
        ###
        tasks = [
            (callback) ->
                WaveProcessor.getWaveByUrl(waveUrl, callback)
            (wave, callback) ->
                creator = wave.getTopicCreator()
                return callback(new WaveError("Topic has no creator")) if not creator
                UserCouchProcessor.getByIdsAsDict([creator.id, user.id], (err, users) ->
                    return callback(err, null) if err
                    creator = users[creator.id]
                    user = users[user.id]
                    return callback(new DbError('not_found')) if not user or not creator
                    callback(null, wave, creator, user)
                )
            (wave, creator, user, callback) ->
                BlipProcessor.getBlip(wave.rootBlipId, (err, rootBlip) ->
                    return callback(err, null) if err
                    callback(null, wave, creator, user, rootBlip)
                , false, false)
            (wave, creator, user, rootBlip, callback) ->
                context =
                    waveUrl: wave.getUrl()
                    waveTopic: rootBlip.getTitle()
                    from: user
                Notificator.notificateUser(creator, 'access_request', context, callback)
        ]
        async.waterfall(tasks, callback)

module.exports.WaveNotificator = new WaveNotificator()
