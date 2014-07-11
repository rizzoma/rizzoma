async = require('async')
{ImapConnection} = require('imap')
{MailParser} = require('mailparser')
{Conf} = require('../../conf')
{ParsedMail} = require('./parsed_mail')


class ImapEmailFetcher
    ###
    Берет из специального ящика специальные письма с ответами на блипы
    ###
    constructor: () ->
        @_logger = Conf.getLogger('imap-email-fetcher')
        @_months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        @SEARCH_TIME_LIMIT = 86400 # в секундах за сколько часов назад выгребать пиьсма
        conf = Conf.get('emailReplyFetcher').imap
        @_imap = new ImapConnection(conf)

    connect: (callback) ->
        tasks = [
            (callback) =>
                @_imap.connect(callback)
            (callback) =>
                @_imap.openBox('INBOX', false, callback)
        ]
        async.waterfall(tasks, callback)

    on: (event, callback) ->
        @_imap.on(event, callback)

    _parseMail: (mail) ->
        ###
        Достает необходимую инфу из мыла
        ###
        address = mail.to[0].address
        from = mail.from[0].address
        idsData = address.substring(address.indexOf('+') + 1, address.indexOf('@'))
        [waveUrl, blipId, random] = idsData.split('/')
        parsedMail = new ParsedMail(from, waveUrl, blipId, random, mail.text, mail.html, mail.headers)
        @_logger.info("Got mail #{parsedMail.getId()} from #{parsedMail.from} ", parsedMail)
        return parsedMail

    _parseMsg: (msg, callback) ->
        ###
        Разбирает одно письмо
        ###
        mp = new MailParser()
        mp.on('end', (mailObject) =>
            mail = @_parseMail(mailObject)
            callback(null, mail)
        )
        msg.on('data', (chunk) ->
            mp.write(chunk)
        )
        msg.on('end', () ->
            mp.end()
        )

    _fetchSearchResults: (results, callback) ->
        ###
        фетчит результаты поиска в инбоксе и возвращает массив объектов писем
        ###
        return callback(null, []) if not results.length
        fetch = @_imap.fetch(results, {
            request:
                struct: false
                body: "full"
                headers: false
            markSeen: true
        })
        mails = []
        fetch.on('message', (msg) =>
            @_parseMsg(msg, (err, mail) =>
                mails.push(mail)
                if results.length == mails.length
                    @_logger.info("Done parsing mails!")
                    callback(null, mails)
            )
        )
        fetch.on('end', () =>
            @_logger.info("Done fetching mails!")
        )

    fetchMails: (callback) ->
        @_logger.info("Imap fetcher started")
        tasks = [
            (callback) =>
                yesterday = new Date(Date.now() - @SEARCH_TIME_LIMIT * 1000)
                #   date должен быть в формате "August 24, 2012"
                date = "#{@_months[yesterday.getMonth()]} #{yesterday.getDate()}, #{yesterday.getFullYear()}"
                @_imap.search([ 'UNSEEN', ['SINCE', date] ], callback)
            (results, callback) =>
                @_fetchSearchResults(results, callback)
            (mails, callback) =>
                @_logger.info("Imap fetcher finished, fetched #{mails.length} mails")
                callback(null, mails)
        ]
        async.waterfall(tasks, callback)

module.exports.ImapEmailFetcher = ImapEmailFetcher