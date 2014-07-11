renderAnonymousNotification = require('./template').renderAnonymousNotification
History = require('../../utils/history_navigation')

CALL_TO_ACTION_VARIANT_A = ['Sign in to view and comment']
CALL_TO_ACTION_VARIANT_B = ['Anonymous access is disabled', 'Sign in to view the discussion']

class AnonymousNotification
    ###
    Класс, выдающий уведомление о необходимости авторизоваться
    ###

    constructor: () ->
        ###
        @param _error: object, объект ошибки
        ###
        @_$container = $(document.body)
        @_$container.find('.js-anonymous-notification-container').remove()
        @_$container.find('.js-log-out-container').remove()
        @_createDOM()

    _createDOM: ->
        ###
        Создает DOM для показа уведомления
        ###
        urlParams = History.getCurrentParams()

        variant = Math.round(Math.random()) is 1
        if variant
            varStr = '"Anonymous access" slogan'
            callToAction = CALL_TO_ACTION_VARIANT_B
        else
            varStr = '"sign in" slogan'
            callToAction = CALL_TO_ACTION_VARIANT_A

        _gaq.push(['_setCustomVar', 5, 'topic landing', varStr, 2])
        _gaq.push(['_trackPageview', '/unauthorized'+document.location.pathname+document.location.search;])
        _gaq.push(window.cleanupAnalytics) if window.cleanupAnalytics and document.location.search

        redirectUrl = History.getLoginRedirectUrl()
        @_$container.append renderAnonymousNotification({callToAction: callToAction, redirectUrl: redirectUrl, variant: variant})

module.exports.AnonymousNotification = AnonymousNotification