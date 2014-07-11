Conf = require('../../conf').Conf
fs = require('fs-plus')
path = require('path')
NotificationError = require('../exceptions').NotificationError

class NotificationTransport
    ###
    Базовый класс нотификатора
    ###

    constructor: (@_conf) ->
        @_logger = Conf.getLogger('notification')

    notificateUser: (user, template, context, callback) ->
        ###
        Should return meta object in callback
        meta =
            transport: trName
            type: type
            from: @jid
            to: user.email
            subject: message
            isNewUser: not user.firstVisit
            success: @_cl.state == STATUS_ONLINE
        ###
        return callback(new NotificationError('Wrong settings for transport'), {}) if not @_conf
        
    init: () ->

    close: () ->

    @getCommunicationType: () ->
        ###
        возвращает тип транспорта как в настройках клиента
        ###
        return null

    _getTemplatePath: (templateName) ->
        return 'notification/'

    _getTemplate: (type, isRegisteredUser, suffix) ->
        ###
        Возвращает имя шаблона
        если пользователь не зарегистрирован
        сначала ищет шаблон для незареганного пользователя, а затем уже обычный
        ###
        if not isRegisteredUser
            templateName = "#{@_getTemplatePath(type)}_not_registered#{suffix}"
            return templateName if fs.existsSync(path.join(Conf.getTemplateRootDir(), templateName))
        return "#{@_getTemplatePath(type)}#{suffix}"

    _renderMessage: (templateName, context, callback) ->
        try
            callback null, Conf.getTemplate().compileFile(templateName).render(context)
        catch e
            callback(e, null)

module.exports.NotificationTransport = NotificationTransport
