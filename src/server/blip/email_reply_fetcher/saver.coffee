_ = require('underscore')
async = require('async')
{Conf} = require('../../conf')
{BlipController} = require('../controller')
{BlipProcessor} = require('../processor')
{CouchBlipProcessor} = require('../couch_processor')
{CouchWaveProcessor} = require('../../wave/couch_processor')
{UserCouchProcessor} = require('../../user/couch_processor')
{EmailBodyParser} = require('./body_parser')
{ACTIONS} = require('../../wave/constants')


class EmailReplySaver

    constructor: () ->
        @_logger = Conf.getLogger('email-reply-saver')

    _composeBlipInsertOp: (blip, parent, answerBlipId) ->
        ###
        Компонует операцию вставки блипа ответа
        ###
        op = {}
        op['ti'] = ' '
        op.params =
            "__TYPE": "BLIP"
            "__ID": answerBlipId
            "RANDOM": Math.random()
        parent.iterateBlocks((blockType, block, position) ->
            return if blockType != 'BLIP'
            if block.params.__ID is blip.id
                op.p = position + block.t.length
                op.params.__THREAD_ID = block.params.__THREAD_ID or blip.id
                op.params.shiftLeft = true
        )
        return op

    _getAnswerBlipContent: (mail) ->
        content = EmailBodyParser.getBlipContent(mail)
        if content.length and content[0].params.__TYPE != 'LINE'
            content.unshift({t: ' ', params: {__TYPE: 'LINE', RANDOM: Math.random()}})
        return content

    _saveAnswerBlip: (mail, blip, parent, user, callback) ->
        ###
        Создает и вставляет блип ответа
        ###
        content = @_getAnswerBlipContent(mail)
        BlipProcessor.createAnswerBlip(parent, blip.id, user, content, callback)

    _saveAnswerBlips: (mails, blips, parents, users, callback) ->
        ###
        Создает и вставляет блипы ответов
        ###
        tasks = {}
        for mail in mails
            blip = blips[mail.blipId]
            parent = parents[mail.blipId]
            userId = blip.notificationRecipients[mail.random]
            user = users[userId]
            tasks[mail.getId()] = (do(mail, blip, parent, user) =>
                return (callback) =>
                    @_saveAnswerBlip(mail, blip, parent, user, (err, res) ->
                        callback(null, err)
                    )
            )
        async.series(tasks, callback)

    _loadWaves: (blips, callback) ->
        ###
        Загружает топики
        ###
        waveIds = {}
        for blipId, blip of blips
            waveIds[blip.waveId] = blip.waveId
        waveIds = _.keys(waveIds)
        CouchWaveProcessor.getByIdsAsDict(waveIds, callback)

    _loadUsers: (mails, blips, callback) ->
        ###
        Загружает пользователей
        ###
        userIds = {}
        for mail in mails
            blip = blips[mail.blipId]
            continue if not blip
            userId = blip.notificationRecipients[mail.random]
            continue if not userId
            userIds[userId] = userId
        userIds = _.keys(userIds)
        return callback(null, {}) if not userIds.length
        UserCouchProcessor.getByIdsAsDict(userIds, callback)

    _checkMailParams: (mail) ->
        ###
        Проверяет правильность параметров письма
        ###
        return new Error("Empty waveUrl, can't find topic") if not mail.waveUrl
        return new Error("Empty blipId, can't find blip") if not mail.blipId
        return new Error("Empty random, can't find user") if not mail.random
        return null

    _checkMailsParams: (mails) ->
        ###
        проверяет правильность заполнения парметров письма
        @returns; Object - {checkedMails: Array, errors: {mailId: error}]
        ###
        checkedMails = []
        errors = {}
        for mail in mails
            err = @_checkMailParams(mail)
            checkedMails.push(mail) if not err
            errors[mail.getId()] = err
        return [checkedMails, errors]

    _getBlipIds: (mails) ->
        ###
        Собирает id блипов из писем
        ###
        return (mail.blipId for mail in mails)

    _checkMailData: (mail, blips, waves, parents, users) ->
        ###
        Проверяет корректность данных из письма и права контрибутора
        @returns; null|Error
        ###
        blip = blips[mail.blipId]
        return new Error("Blip #{mail.blipId} not found in db") if not blip
        wave = waves[blip.waveId]
        return new Error("Wave #{mail.waveUrl} not found in db") if not wave
        return new Error("Blip #{mail.blipId} is not in the #{mail.waveUrl} topic") if wave.getUrl() != mail.waveUrl
        parent = parents[mail.blipId]
        return new Error("ParentBlip for blip #{mail.blipId} not found in db") if not parent
        userId = blip.notificationRecipients[mail.random]
        return new Error("UserId not found by random #{mail.random}") if not userId
        user = users[userId]
        err = wave.checkPermission(user, ACTIONS.ACTION_COMMENT)
        return err if err
        return null

    _checkMailsData: (mails, blips, waves, parents, users) ->
        ###
        Проверяет корректность данных из письма и права контрибутора
        @returns; Object - {checkedMails: Array, errors: {mailId: error}]
        ###
        errors = {}
        checkedMails = []
        for mail in mails
            err = @_checkMailData(mail, blips, waves, parents, users)
            if err
                errors[mail.getId()] = err
            else
                checkedMails.push(mail)
        return [checkedMails, errors]

    save: (mails, callback) ->
        @_logger.info("Reply saver started")
        [mails, errors]= @_checkMailsParams(mails)
        @_logger.info("Mails params checked, correct #{mails.length} mails")
        if not mails.length
            @_logger.info("Reply saver finished")
            return callback(null, errors)
        blipIds = @_getBlipIds(mails)
        tasks = [
            (callback) ->
                CouchBlipProcessor.getByIdsAsDict(blipIds, callback)
            (blips, callback) =>
                @_logger.info("Loaded #{_.keys(blips).length} blips")
                @_loadWaves(blips, (err, waves) =>
                    return callback(err) if err
                    @_logger.info("Loaded #{_.keys(waves).length} waves")
                    callback(null, blips, waves)
                )
            (blips, waves, callback) =>
                CouchBlipProcessor.getByChildIds(blipIds, (err, parents) =>
                    return callback(err) if err
                    @_logger.info("Loaded #{_.keys(parents).length} parent blips")
                    callback(null, blips, waves, parents)
                )
            (blips, waves, parents, callback) =>
                @_loadUsers(mails, blips, (err, users) =>
                    return callback(err) if err
                    @_logger.info("Loaded #{_.keys(users).length} users")
                    callback(null, blips, waves, parents, users)
                )
            (blips, waves, parents, users, callback) =>
                [mails, errs] = @_checkMailsData(mails, blips, waves, parents, users)
                @_logger.info("Mails data checked, correct #{mails.length} mails")
                errors = _.extend(errors, errs)
                return callback(null) if not mails.length
                @_saveAnswerBlips(mails, blips, parents, users, (err, errs) =>
                    return callback(err) if err
                    savedReplies = []
                    for mail in mails
                        mailId = mail.getId()
                        err = errs[mailId]
                        if err
                            errors[mailId] = err
                        else
                            blip = blips[mail.blipId]
                            parent = parents[mail.blipId]
                            userId = blip.notificationRecipients[mail.random]
                            user = users[userId]
                            @_logger.info("Reply saved #{mailId} from #{user.email} to #{parent.getAuthorId()}")
                            savedReplies.push(mailId)
                    @_logger.info("Saved #{savedReplies.length} replies")
                    callback(null)
                )
        ]
        async.waterfall(tasks, (err) =>
            @_logger.info("Reply saver finished")
            for mailId, err of errors
                @_logger.error("Error occurred with #{mailId}", err) if err
            callback(err, errors)
        )

module.exports.EmailReplySaver = EmailReplySaver
