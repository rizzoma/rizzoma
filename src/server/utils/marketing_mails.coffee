async = require('async')
Conf = require('../conf').Conf
logger = Conf.getLogger('marketing_mails')
SmtpTransport = require('../notification/transport/smtp').SmtpTransport

class MarketingMailer
    constructor: () ->
        conf = Conf.getNotificationConf()
        @_smtp = new SmtpTransport(conf.transport.smtp)
        @_smtp.init()
        @_timeout = 1 # seconds between mails

    run: (recipientsFile, callback) ->
        recipients = @_parseRecipients(recipientsFile)
        # следующую строку необходимо раскомментировать, чтобы пошла реальная отправка писем 
        #@_sendMails(recipients, callback)

    _parseRecipients: (recipientsFile) ->
        ###
        Загружает и разбирает текстовый файл с email получателей и данными для писем.
        Строки в файле разделяются \n (перенос строки), каждая строка - это одно отправляемое письмо.
        Поля в файле разделяются символом табуляции. В одном из полей должен быть указан email получателя,
        в остальных полях указываются дополнительные данные, которые будут переданы в шаблон письма.
        ###
        fs = require('fs')
        t = fs.readFileSync(recipientsFile).toString()
        lines = t.trim().split(/\s*\n\s*/)

        recipients = []
        for line, i in lines
            parts = line.split(/\t/)
            # parts - это поля одной строки.
            partsCount = 7 # количество полей в каждой строке. Если полей будет не столько, то строка будет пропущена.
            emailPartNumber = 3 # номер поля с email получателя. Нумерация с нуля (т.е. 3 - это четвертое поле).
            if parts.length == partsCount and parts[emailPartNumber].indexOf('@') != -1
                # Разбирает поля и раскладывает их по переменным.
                # "to" - это email получателя, остальные поля можно называть как угодно,
                # по этим названиям к ним можно будет доступиться в шаблоне.
                recipients.push {to: parts[emailPartNumber], name: parts[2], post: parts[5], postUrl: parts[6]}
            else
                logger.warn ("Bad line #{i+1}: '#{line}', skiping")

        logger.debug(recipients)
        logger.info("Got #{recipients.length} recipients")

        return recipients
#        return [
#            {to:'yuryilinikh@gmail.com', name: 'Yury', post: 'My awesome post header about Education', postUrl: 'http://mypost.com'}
#        ]

    _sendMails: (recipients, callback) ->
        tasks = []
        for recipient in recipients
            tasks.push do(recipient) =>
                return (callback) =>
                    context = recipient
                    # Если в письме должны быть аттачменты, то раскомментировать следующие строки.
                    # Для каждого аттачмента указывается имя файла и путь, откуда его брать,
                    # а также "cid" - имя, по которому его можно будет адресовывать в html-коде письма:
                    # картинку с cid:'GW_users.png' в html можно будет подключить конструкцией
                    # <img src="cid:GW_users.png" alt="описание картинки" />.
#                    context.attachments = [
#                        {fileName: 'GW_users.png', cid: 'GW_users.png', filePath: 'src/static/img/marketing_mails/gw_users.png'}
#                    ]
                    @_smtp.notificateUser({email: recipient.to}, 'marketing_blogger_mail_3', context, (err, res) =>
                        setTimeout(() =>
                            callback(null, err)
                        , @_timeout * 1000 )
                    )

        async.series(tasks, (err, res) ->
            logger.info(res)
            callback?(null)
        )

module.exports.MarketingMailer = new MarketingMailer
