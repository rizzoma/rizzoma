ck = window.CoffeeKup
{KeyCodes} = require('../utils/key_codes')
{isEmail} = require('../../share/utils/string')
{contactsUpdateWindowParams} = require('../wave/processor')

mergePopupTmpl = ->
    div ->
        div '.js-notification-overlay.notification-overlay', ''
        div '.notification-block', ->
            div '.js-account-merge-form-container.account-merge-form-container', ->
                div '.js-merge-close.merge-close', {title: 'Close'}, ''
                div '.merge-title', 'Merge your accounts'
                div '.js-merge-content.merge-content', ->
                    div ->
                        text "You're signed in as "
                        span '.bold', "#{h(if @currentName then @currentName+' ('+@currentEmail+')' else @currentEmail)}"
                        text "."
                    if @email?
                        div ->
                            text "Attention! You could be missing some topics because you were invited by another email "
                            span '.bold', "#{h(@email)}"
                            text ". Please sign in using #{h(@email)} or join it to your current account."
                    else
                        div ->
                            text "You can join some other account to use them for authorization in Rizzoma.com or to be invited"
                        div '.merge-button-block', ->
                            button '.js-google-account.button', 'Join Google account'
                            button '.js-facebook-account.button', 'Join Facebook account'
                    div '.js-secondary-email-container', ->
                        div 'Add another email to your account'
                        div '.secondary-email-block', ->
                            input '.js-secondary-email-input.secondary-email-input', {type: 'text', placeholder: 'Email address', value: h(@email or '')}
                            button '.js-send-secondary-email.send-secondary-email.button', 'Join'
                        div '.js-email-error.merge-error.hidden', 'Invalid email'

renderMergePopup = ck.compile(mergePopupTmpl)

emailSentTmpl = ->
    div '.merge-message', "Merging request accepted. An email with next step has been sent to #{h(@email)}. Please follow it."
renderEmailSent = ck.compile(emailSentTmpl)

mergeErrorTmpl = ->
    div '.merge-error', ->
        text "Merging request rejected."
        text " #{@error.message}." if @error?.message
renderMergeError = ck.compile(mergeErrorTmpl)

successfullyMergedTmpl = ->
    div '.merge-message', ->
        text "Successfully merged. "
        a href: "/topic/", "Reload page"
        text "."
renderSuccessfullyMerged = ck.compile(successfullyMergedTmpl)

mergeConfirmTmpl = ->
    avatar = '/s/img/user/unknown.png'
    div '.avatar-block', style: "background-image: url(#{@currentAvatar or avatar});", ->
        text "You're signed in as "
        span '.bold', "#{h(if @currentName then @currentName+' ('+@currentEmail+')' else @currentEmail)}"
        text "."
    div '.avatar-block', style: "background-image: url(#{@newAvatar or avatar});", ->
        text "Please confirm joining #{h(if @newSource then @newSource.charAt(0).toUpperCase() + @newSource.slice(1) else '')} profile "
        span '.bold', "#{h(if @newName then @newName+' ('+@newEmail+')' else @newEmail)}"
        text " with your current account."
    div '.js-confirm-button-block.confirm-button-block', ->
        button '.js-ok-button.button', 'Ok'
        button '.js-cancel-button.button', 'Cancel'
renderMergeConfirm = ck.compile(mergeConfirmTmpl)

class AccountMergePopup
    constructor: (@_email) ->

    show: ->
        _gaq.push(['_trackEvent', 'Account merging', 'Show account merging', if @_email then 'from email' else 'from profile'])
        @_$container = $(renderMergePopup({email: @_email, currentName: window.userInfo.name, currentEmail: window.userInfo.email}))
        $('.js-secondary-email-input').placeholder?()
        $(document.body).append(@_$container)
        @_initClose()
        @_initEmailInput()
        @_initMergeButtons()

    _initClose: ->
        @_$container.find('.js-notification-overlay, .js-merge-close').click(@_close)
        $(window).keydown(@_windowKeyHandler)

    _windowKeyHandler: (e) =>
        @_close(e) if e.which is KeyCodes.KEY_ESCAPE

    _initEmailInput: ->
        @_$input = @_$container.find('.js-secondary-email-input')
        @_$input.keypress (e) =>
            return if e.which isnt KeyCodes.KEY_ENTER
            @_sendEmail(@_$input.val())
        @_$container.find('.js-send-secondary-email').click =>
            @_sendEmail(@_$input.val())
        @_$input.focus()

    _initMergeButtons: ->
        @_$container.find('.js-google-account').click =>
            @_openMergeByOauthWindow('google')
        @_$container.find('.js-facebook-account').click =>
            @_openMergeByOauthWindow('facebook')
        window.mergeByOauth = (profile, code) =>
            profile = JSON.parse(profile)
            $block = @_$container.find('.js-merge-content').empty()
            params =
                newAvatar: profile.avatar
                newSource: profile.source
                newName: profile.name
                newEmail: profile.email
                currentAvatar: window.userInfo.avatar
                currentName: window.userInfo.name
                currentEmail: window.userInfo.email
            $block.append(renderMergeConfirm(params))
            $block.find('.js-ok-button').click =>
                require('../user/processor').instance.mergeByOauth code, (err) =>
                    @_hideConfirmButtonBlock()
                    if err
                        console.error("Could not merge (OAuth)", err)
                        @_addMergeError(err)
                    else
                        @_addSuccessfullyMerged()
            $block.find('.js-cancel-button').click(@_close)
            @_$container.find('.js-account-merge-form-container').width(400)

    _openMergeByOauthWindow: (source) ->
        _gaq.push(['_trackEvent', 'Account merging', 'Do merging', "#{source} button"])
        params = contactsUpdateWindowParams[source]
        window.open("/accounts_merge/#{source}/", 'Loading', "width=#{params.width},height=#{params.height}")

    _sendEmail: (email) ->
        domain = email.match(/@(.+)/)
        if domain
            domain = domain[1]
        else
            domain = 'invalid'
        $emailError = @_$container.find('.js-email-error')
        if not isEmail(email)
            return $emailError.removeClass('hidden')
        $emailError.addClass('hidden')
        if domain is 'gmail.com' or domain is 'googlemail.com'
            return @_openMergeByOauthWindow('google')
        if domain is 'facebook.com'
            return @_openMergeByOauthWindow('facebook')
        @_hideEmail()
        _gaq.push(['_trackEvent', 'Account merging', 'Do merging', domain])
        require('../user/processor').instance.prepareMerge email, (err, res) =>
            if err
                console.error("Could not merge (email)", err)
                @_addMergeError(err)
            else
                @_addEmailSent(email)

    _addEmailSent: (email) ->
        @_addMessage(renderEmailSent({email}))

    _addMergeError: (error) ->
        @_addMessage(renderMergeError({error}))

    _addSuccessfullyMerged: ->
        @_addMessage(renderSuccessfullyMerged())

    _addMessage: (html) ->
        @_$container.find('.js-merge-content').append(html)

    _hideEmail: ->
        @_$container.find('.js-secondary-email-container').addClass('hidden')

    _hideConfirmButtonBlock: ->
        @_$container.find('.js-confirm-button-block').addClass('hidden')

    _close: (e) =>
        e.stopPropagation()
        e.preventDefault()
        $(window).off('keydown', @_windowKeyHandler)
        @_$container.remove()
        delete window.mergeByOauth

module.exports = {AccountMergePopup}