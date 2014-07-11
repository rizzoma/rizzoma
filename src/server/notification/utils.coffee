crypto = require('crypto')
Conf = require('../conf').Conf

# соль для криптования email отписки
HASH_SALT = '[csap0r94285jh][;s09u'
imgPath = "#{Conf.get('staticSrcPath')}img/"

module.exports.Utils =
    getEmailHash: (email) ->
        ###
        Возвращает соленый хеш от мыла
        ###
        hash = crypto.createHash('md5');
        hash.update(HASH_SALT + email);
        return hash.digest('hex')

    getBubbleAttachments: () ->
        ###
        Возвращает аттачи с картинками для письма с облачком
        ###
        return [
            {fileName: 'bubble-left-top-border.png', cid: 'bubble-left-top-border.png', filePath: "#{imgPath}mail/bubble-left-top-border.png"}
            {fileName: 'bubble-top-border.png', cid: 'bubble-top-border.png', filePath: "#{imgPath}mail/bubble-top-border.png"}
            {fileName: 'bubble-top-triangle-border.png', cid: 'bubble-top-triangle-border.png', filePath: "#{imgPath}mail/bubble-top-triangle-border.png"}
            {fileName: 'bubble-right-top-border.png', cid: 'bubble-right-top-border.png', filePath: "#{imgPath}mail/bubble-right-top-border.png"}
            {fileName: 'bubble-right-border.png', cid: 'bubble-right-border.png', filePath: "#{imgPath}mail/bubble-right-border.png"}
            {fileName: 'bubble-right-bottom-border.png', cid: 'bubble-right-bottom-border.png', filePath: "#{imgPath}mail/bubble-right-bottom-border.png"}
            {fileName: 'bubble-bottom-border.png', cid: 'bubble-bottom-border.png', filePath: "#{imgPath}mail/bubble-bottom-border.png"}
            {fileName: 'bubble-left-bottom-border.png', cid: 'bubble-left-bottom-border.png', filePath: "#{imgPath}mail/bubble-left-bottom-border.png"}
            {fileName: 'bubble-left-border.png', cid: 'bubble-left-border.png', filePath: "#{imgPath}mail/bubble-left-border.png"}
        ]

    getLogoAttachments: () ->
        ###
        Возвращает аттачи с картинками лого
        ###
        return [{fileName: 'rizzoma-logo.png', cid: 'rizzoma-logo.png', filePath: "#{imgPath}logo/75.png"}]

    getMailLogoAttachments: () ->
        ###
        Возвращает аттачи с картинками лого
        ###
        return [{fileName: 'rizzoma-mail-logo.png', cid: 'rizzoma-mail-logo.png', filePath: "#{imgPath}logo/mail-logo.png"}]

    getLogoAndBubbleAttachments: () ->
        ###
        Возвращает аттачи с картинками для письма с облачком и логой
        ###
        return @getLogoAttachments().concat(@getBubbleAttachments())

    generateNotificationRandom: () ->
        ###
        Генерит уникальную сточку для письма
        используется в email_reply_fetcher для поиска пользователя
        ###
        return Math.random() + ""
