async = require('async')
{Conf} = require('../../conf')
{ImapEmailFetcher} = require('./imap_fetcher')
{AmqpSaveManager} = require('./amqp_saver')


class EmailReplyFetcher
    constructor: () ->
        @_logger = Conf.getLogger('email-reply-fetcher')
        @_busy = false
        @_hasDelayedRequests = false
        @_fetcher = new ImapEmailFetcher()
        @_saver = new AmqpSaveManager()
        # поставим чтобы выходил каждые 30 минут (sec)
        @RUN_TIME_LIMIT = 30 * 60
        # если установлен то выполняется по завершению процесса фетчинга писем
        @_processFinishedCallback = null

    _fetch: (callback) ->
        tasks = [
            (callback) =>
                @_fetcher.fetchMails(callback)
            (mails, callback) =>
                return callback(null) if not mails.length
                @_saver.save(mails, callback)
        ]
        async.waterfall(tasks, (err) =>
            @_logger.error(err) if err
            callback?(err)
        )

    _process: () ->
        if @_busy
            @_hasDelayedRequests = true
            return
        @_busy = true
        @_fetch(() =>
            if @_hasDelayedRequests
                @_hasDelayedRequests = false
                @_process()
            else
                @_busy = false
                @_processFinishedCallback?()
        )

    _setExitTimeout: () ->
        setTimeout(() =>
            if not @_busy
                @_logger.info("Finshed")
                return process.exit(0)
            @_processFinishedCallback = ->
                @_logger.info("Finshed")
                process.exit(0)
        , @RUN_TIME_LIMIT * 1000)

    _delayedExit: () ->
        ###
        если отконнектились выходим чз 1.5 минуты
        ###
        setTimeout(() =>
            @_logger.info("Finshed")
            return process.exit(0)
        , 90 * 1000)

    run: (callback) ->
        ###
        Начало всея
        ###
        @_logger.info("Started")
        # поставим чтобы выходил каждые 30 минут
        @_setExitTimeout()
        @_fetcher.on('error', (err) =>
            @_logger.error(err)
            @_delayedExit()
        )
        @_fetcher.on('end', () =>
            @_delayedExit()
        )
        @_fetcher.on('close', () =>
            @_delayedExit()
        )
        @_fetcher.on('mail', (num) =>
            @_logger.info("Received #{num} new mails")
            @_process()
        )
        @_fetcher.connect(() =>
            @_process()
        )

module.exports =
    EmailReplyFetcher: new EmailReplyFetcher()