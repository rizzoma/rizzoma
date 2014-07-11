{BaseModule} = require('../../../share/base_module')
renderError = require('./template').renderError
AnonymousNotification = require('../../wave/notification/anonymous_notification').AnonymousNotification
{NEED_MERGE_ERROR_CODE} = require('../../../share/constants')
{AccountMergePopup} = require('../../account_merge')
History = require('../../utils/history_navigation')

class PageError extends BaseModule
    ###
    Модуль для отображения ошибок страницы, которые требуют перезагрузки страницы
    ###
    constructor: (args...) ->
        super args...
        @_errorShown = false
        $(document).ready =>
            @_createDOM()
    
    _createDOM: ->
        ###
        Создает необходимые элементы для отображения ошибки
        ###
        @_container = $('.js-page-error-container')[0]
        @_text = $('.js-page-error')[0]
        @showError() if @_errorShown

    _updateRefreshLink: ->
        ###
        Обновляет ссылку "Обновить" для того, чтобы пользователь попал на ту же
        страницу после ее нажатия
        ###
        return if not @_refreshLink
        @_refreshLink.href = location.href
    
    _processRefreshLinkClick: (event) =>
        ###
        Обрабатывает нажатие на ссылку "Обновить". Сам браузер не перезагружает страницу
        при клике на эту ссылку.
        ###
        event.preventDefault()
        location.reload()

    showError: (request, args, callback) ->
        ###
        Показывает ошибку на странице, предлагает пользователю обновить страницу
        ###
        if request.args.error.code == 'wave_anonymous_permission_denied'
            window.AuthDialog.initAndShow(false, History.getLoginRedirectUrl())
            return
        if request.args.error.code is NEED_MERGE_ERROR_CODE
            (new AccountMergePopup(request.args.error.message)).show()
            return
        @_errorShown = true
        return if not @_container
        if not request.args.error.code
            if typeof request.args.error is 'string'
                msg = request.args.error
            else if request.args.error.msg?
                msg = request.args.error.msg
            else if request.args.error.message?
                msg = request.args.error.message
            else msg = 'showError (I)'
            if /Deleted text .+ is not equal to text in operation/.test(msg)
                msg = 'Deleteted text is not equal to text in operation'
            else if /Text block params .+ do not equal to op params/.test(msg)
                msg = 'Text block params do not equal to op params'
            else if /Expected version .+ but got/.test(msg)
                msg = 'Expected version X but got Y'
            else if /Specified position .+ is more then text length/.test(msg)
                msg = 'Specified position X is more then text length N'
            _gaq.push(['_trackEvent', 'Error', 'Client error', msg])
        @__logError(request.args.error)
        c = $(@_text)
        c.empty()
        c.append renderError(request.args)
        $(@_container).addClass('error-shown')
        @_refreshLink = c.find('.js-refresh-link')[0]
        $(window).bind('hashchange', @_updateRefreshLink)
        $(@_refreshLink).bind('click', @_processRefreshLinkClick)
        @_updateRefreshLink()

    __logError: (error) ->
        require('../../error_logger/module').instance.logError(error)


module.exports.PageError = PageError
