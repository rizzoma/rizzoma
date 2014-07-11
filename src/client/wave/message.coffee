###
Класс для отображения сообщений на месте топика
###
History = require('../utils/history_navigation')
{AccountMergePopup} = require('../account_merge')
{AccountMenu} = require('./account_menu')
{renderWaveHeaderMobile} = require('./template')
{WAVE_PERMISSION_DENIED_ERROR_CODE,
 NEED_MERGE_ERROR_CODE,
 WAVE_DOCUMENT_DOES_NOT_EXISTS_ERROR_CODE,
 WAVE_ANONYMOUS_PERMISSION_DENIED_ERROR_CODE
} = require('../../share/constants')

ck = window.CoffeeKup
renderMessage = ck.compile ->
    div '.topic-message-container.js-topic-message-container', ''

renderCreatingWait = ck.compile ->
    div '.message-container', ->
        div '.wait-icon', {title: 'Creating topic'}
        div 'Creating topic'

renderLoadingWait = ck.compile ->
    div '.message-container', ->
        div '.wait-icon', {title: 'Loading topic'}
        div 'Loading topic'

renderCommonLoadingError = ck.compile ->
    div '.message-container', ->
        div '.reload-icon', {title: 'Reload topic'}
        div h(@error.message || 'Some error occurred while loading') + '.'
        div '', ->
            if @error.logId
                text "Error code #{h(@error.logId)}. "
            text 'Please, '
            button '.js-reload-topic-button', 'reload topic'
            text '.'

renderAccessDeniedLoadingError = ck.compile ->
    div '.message-container.js-access-denied-container', ->
        div '.lock-icon', {title: 'Access denied'}
        div 'You need permission to join this topic'
        button '.js-ask-for-access-button.ask-for-access-button', 'Ask for access'
        div '.asked-for-access-container', ->
            text 'You asked for access. '
            button '.js-reload-topic-button', 'Reload'
            text '.'

renderNotFoundLoadingError = ck.compile ->
    div '.message-container', ->
        div '.attention-icon', {title: 'Topic not found'}
        div 'Requested topic not found'

renderCreatingError = ck.compile ->
    div '.message-container', ->
        div '.attention-icon', {title: 'Topic was not created'}
        div h(@error.message || 'Some error occurred while creating topic') + '.'
        div '', ->
            if @error.logId
                text "Error code #{h(@error.logId)}. "
            button '.js-retry-create-button', 'Retry'
            text '.'

renderCreateTopicMessage = ck.compile ->
    div '.message-container', ->
        div 'Select topic from list or create new topic'
        button '.js-create-wave.create-wave', {title:"Create new topic"}, 'Create new topic'

renderMessageBodyMobile = ck.compile ->
    section '.topic-message-container.js-topic-message-container', ''

class WaveMessage
    constructor: (@container) ->
        @_createDOM()
        @_initAccountMenu()

    _preprocessError: (error) ->
        # Удалим сообщение для InternalError, т.к. оно не оформлено для человека
        delete error.message if error.type is 'InternalError'

    _createDOM: ->
        c = $(@container)
        c.empty()
        c.append(renderMessage())
        @_$messageContainer = c.find('.js-topic-message-container')

    _initAccountMenu: ->
        menu = new AccountMenu()
        menu.render($('.js-account-container')[0])

    _replaceMessage: (html) ->
        @_$messageContainer.empty()
        @_$messageContainer.html(html)

    showCreatingWait: ->
        @_replaceMessage(renderCreatingWait())
        @_$messageContainer.addClass('loading')

    showLoadingWait: ->
        @_replaceMessage(renderLoadingWait())
        @_$messageContainer.addClass('loading')

    showLoadingError: (error, waveId, retry) ->
        @_preprocessError(error)
        switch error.code
            when WAVE_PERMISSION_DENIED_ERROR_CODE
                @_showAccessDeniedLoadingError(waveId, retry)
                break
            when WAVE_DOCUMENT_DOES_NOT_EXISTS_ERROR_CODE
                @_showNotFoundLoadingError()
                break
            when WAVE_ANONYMOUS_PERMISSION_DENIED_ERROR_CODE
                @__showAnonymousAccessDeniedLoadingError()
                break
            when NEED_MERGE_ERROR_CODE
                @__showNeedMergeLoadingError(error, retry)
                break
            else
                @_showCommonLoadingError(error, retry)

    showCreatingError: (error, retry) ->
        @_preprocessError(error)
        @_replaceMessage(renderCreatingError({error}))
        @_$messageContainer.find('.js-retry-create-button').click(retry)

    showCreateTopicButton: ->
        @_replaceMessage(renderCreateTopicMessage())

    _showCommonLoadingError: (error, retry) ->
        @_replaceMessage(renderCommonLoadingError({error}))
        @_$messageContainer.find('.js-reload-topic-button').click(retry)

    _showAccessDeniedLoadingError: (waveId, retry) ->
        @_replaceMessage(renderAccessDeniedLoadingError())
        $accessContainer = @_$messageContainer.find('.js-access-denied-container')
        @_$messageContainer.find('.js-ask-for-access-button').click =>
            _gaq.push(['_trackEvent', 'Topic participants', 'Let me in'])
            require('../processor').instance.sendAccessRequest waveId, (err) =>
                return if @_destroyed
                $accessContainer.addClass('asked-for-access')
                @_$messageContainer.find('.js-reload-topic-button').click(retry)
                console.log("Access request failed") if err

    _showNotFoundLoadingError: ->
        @_replaceMessage(renderNotFoundLoadingError())

    __showAnonymousAccessDeniedLoadingError: ->
        window.AuthDialog.initAndShow(false, History.getLoginRedirectUrl())

    __showNeedMergeLoadingError: (error) ->
        (new AccountMergePopup(error.message)).show()

    destroy: ->
        $(@container).empty()
        @_destroyed = true


class WaveMessageMobile extends WaveMessage
    constructor: (args...) ->
        super(args...)
        @_initHeader()

    _createDOM: ->
        c = $(@container)
        c.empty()
        c.append(renderWaveHeaderMobile() + renderMessageBodyMobile())
        @_$messageContainer = c.find('.js-topic-message-container')

    _initHeader: ->
        @_backButton = @container.getElementsByClassName('js-back-button')[0]
        @_backButton?.addEventListener('click', @_hide, false)

    _hide: =>
        return window.androidJSInterface.onTopicBackButtonClick?() if window.androidJSInterface
        History.navigateTo('', '')
        require('../modules/wave_mobile').instance.hideWavePanel()

    __showAnonymousAccessDeniedLoadingError: ->
        return require('../session/module').Session.setAsLoggedOut()

    __showNeedMergeLoadingError: (error, retry) ->
        targetEmail = error.message
        error.message = "You need permission to join this topic. Sign in as #{targetEmail}."
        @_showCommonLoadingError(error, retry)

    destroy: ->
        @_backButton?.removeEventListener('click', @_hide, false)
        super()


module.exports = {WaveMessage, WaveMessageMobile}