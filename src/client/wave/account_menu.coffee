{AccountMergePopup} = require('../account_merge')
{KeyCodes} = require('../utils/key_codes')
{Request} = require('../../share/communication')
{popup, PopupContent} = require('../popup')
BrowserSupport = require('../utils/browser_support')
{getOtherUrl} = require('../utils/url')

ck = window.CoffeeKup

buttonTmpl = ->
    attrs = {}
    if window.userInfo?.name?
        attrs.title = h(window.userInfo.name)
    button '.js-account-button.account-button', attrs, ->
        return if not window.userInfo?
        div '.avatar', {style: "background-image: url(#{h(window.userInfo.avatar)})"}
        div '.account-show-popup', ''
        
popupTmpl = ->
    isValueAlreadyExist = (where, value) ->
        for _, exist of where
            return true if value is exist
        return false

    getProfileFieldValues = (name) ->
        result = null
        for authId, auth of window.userInfo.profile
            value = auth[name]
            if not value or value is window.userInfo[name]
                continue
            if result and isValueAlreadyExist(result, value)
                continue
            result ?= {}
            result[authId] = value
        return result

    getProfile = ->
        return {} if not window.userInfo.profile
        return {
            names: getProfileFieldValues('name')
            emails: getProfileFieldValues('email')
            avatars: getProfileFieldValues('avatar')
        }

    profile = getProfile()
    div '.js-account-window.account-popup', ->
        div '.avatar-container', ->
            div '.avatar', {style: "background-image: url(#{h(@avatar || window.userInfo.avatar)})"}, ->
                if profile.avatars
                    button '.js-show-avatar-variants.show-variants', {title: 'Choose an avatar to use'}, ''
            if profile.avatars
                ul '.js-avatar-variants.variants', ->
                    for key, avatar of profile.avatars
                        li '.js-variant.avatar-variant', {style: "background-image: url(#{h(avatar)})", 'data-key': h(key)}, ''
        div '.avatar-delimiter', ''
        div '.info', ->
            div '.name', ->
                span h(window.userInfo.name)
                if profile.names
                    button '.js-show-name-variants.show-variants', {title: 'Choose a name to use'}, ''
                    ul '.js-name-variants.variants.name-variants', ->
                        for key, name of profile.names
                            li '.js-variant.name-variant', {'data-key': h(key)}, h(name)
            div '.email', ->
                span h(window.userInfo.email)
                if profile.emails
                    button '.js-show-email-variants.show-variants', {title: 'Choose an email to use'}, ''
                    ul '.js-email-variants.variants.email-variants', ->
                        for key, email of profile.emails
                            li '.js-variant.email-variant', {'data-key': h(key)}, h(email)
            div '.skype-id-container', ->
                input '.js-skype-id-input.skype-id-input', {placeholder: 'Fill in your skypeID', value: h(window.userInfo.skypeId or ''), title: 'Your skypeID'}
                a '.js-skype-status-help.skype-status-help.hidden',
                    {href: 'https://support.skype.com/en/faq/FA605/how-do-i-set-up-the-skype-button-to-show-my-status-on-the-web-in-skype-for-windows-desktop',
                    target: '_blank'}, 'How to make my skype status visible'
            div '.signed-via-container', ->
                authSource = window.userInfo.authSource
                span ".signed-via.#{authSource}", ''
                if authSource is 'password'
                    span '.signed-via-text', "Signed in with password"
                else
                    span '.signed-via-text', "Signed in via #{authSource.charAt(0).toUpperCase() + authSource.slice(1)}"
            div ->
                plan = if @isBusiness then 'Business' else 'Free'
                text "Your current plan is #{plan}. "
                a {href: '/settings/account-menu/', target: '_blank'}, 'Upgrade'
            div "You are #{@role.name.toLowerCase()} of this topic" if @role
            div '.buttons-panel', ->
                button '.button.js-merge-with-account', {title: 'Merge with another account'}, 'Merge'
                a '.button', {href: '/settings/', target: '_blank'}, 'Settings'
                if window.loggedIn
                    a '.button.js-logout', {href: '/logout/', title: 'Log out from Rizzoma'}, 'Sign out'

renderButton = ck.compile(buttonTmpl)
renderPopup = ck.compile(popupTmpl)
if BrowserSupport.isMozilla()
    # В firefox, начиная с 19-й версии есть баг: если одна и та же картинка на странице приводится к разным размера
    # background-size'ом, то firefox потребляет очень много процессорного времени. Изменим url картинки так, чтобы
    # адрес был разным, но картинка - той же
    orgRenderPopup = renderPopup
    renderPopup = (params={}) ->
        params.avatar = getOtherUrl(window.userInfo.avatar)
        orgRenderPopup(params)

class AccountPopup extends PopupContent
    
    constructor: (params, @_reinit) ->
        params ||= {}
        params.isBusiness = require('../account_setup_wizard/processor').instance.isBusinessUser()
        container = $(renderPopup(params))
        container.find('.js-skype-id-input').placeholder?()
        @_container = container[0]
        @_initContainer(container)
        @_initShowNameVariantsButton(container)
        @_initShowEmailVariantsButton(container)
        @_initShowAvatarVariantsButton(container)
        @_initSkypeIdInput(container)
        @_initMergeButton(container)
    
    _initContainer: (container) ->
        container.click (event) ->
            element = $(event.target)
            if not element.hasClass('js-show-name-variants')
                container.find('.js-name-variants').removeClass('visible')
            if not element.hasClass('js-show-email-variants')
                container.find('.js-email-variants').removeClass('visible')
            if not element.hasClass('js-show-avatar-variants')
                container.find('.js-avatar-variants').removeClass('visible')
    
    _getAuthId: (field) ->
        for key, info of window.userInfo.profile
            if info[field] is window.userInfo[field]
                return key
            if field is 'avatar' and window.userInfo.avatar is '/s/img/user/unknown.png' and not info.avatar
                return key
        return null
        
    _changeProfileField: (name, authId) ->
        keys = {}
        for field in ['name', 'email', 'avatar']
            key = @_getAuthId(field)
            return if not key
            keys[field] = key
        keys[name] = authId
        request = new Request keys, (error, user) =>
            return if error
            $.extend window.userInfo,
                name: user.name
                email: user.email
                avatar: user.avatar
            @_reinit()
        router = require('../app').router
        router.handle('network.user.changeProfile', request)
        
    _initShowNameVariantsButton: (container) ->
        button = container.find(".js-show-name-variants")
        return if not button.length
        variants = container.find(".js-name-variants")
        button.click ->
            variants.toggleClass('visible')
        variants.on 'click', '.js-variant', (event) =>
            key = $(event.target).data('key')
            @_changeProfileField('name', key)

    _initShowEmailVariantsButton: (container) ->
        button = container.find(".js-show-email-variants")
        return if not button.length
        variants = container.find(".js-email-variants")
        button.click ->
            variants.toggleClass('visible')
        variants.on 'click', '.js-variant', (event) =>
            key = $(event.target).data('key')
            @_changeProfileField('email', key)

    _initShowAvatarVariantsButton: (container) ->
        button = container.find(".js-show-avatar-variants")
        return if not button.length
        variants = container.find(".js-avatar-variants")
        button.click ->
            variants.toggleClass('visible')
        variants.on 'click', '.js-variant', (event) =>
            key = $(event.target).data('key')
            @_changeProfileField('avatar', key)

    _initSkypeIdInput: (container) ->
        input = container.find('.js-skype-id-input')
        changeSkypeId = (e) ->
            input.blur()
            skypeId = e.target.value
            return if skypeId is window.userInfo.skypeId
            request = new Request {skypeId: skypeId}, (err) ->
                console.warn("Could not set skype id", err) if err
            router = require('../app').router
            router.handle('network.user.setUserSkypeId', request)
            userInfo =
                id: window.userInfo.id
                email: window.userInfo.email
                name: window.userInfo.name
                avatar: window.userInfo.avatar
                skypeId: skypeId
            require('../user/processor').instance.addOrUpdateUsersInfo([userInfo])
            window.userInfo.skypeId = skypeId
        input.change(changeSkypeId)
        input.keypress (e) ->
            return if e.keyCode isnt KeyCodes.KEY_ENTER
            changeSkypeId(e)
        input.focus ->
            container.find('.js-skype-status-help').removeClass('hidden')

    _initMergeButton: (container) ->
        container.find('.js-merge-with-account').click ->
            popup.hide()
            (new AccountMergePopup()).show()
        
    destroy: ->
        
    getContainer: ->
        return @_container

        
class AccountMenu
    
    _initButton: (container, params) ->
        button = container.find('.js-account-button')
        callback = ->
            return if not window.userInfo?
            popup.hide()
            popup.render(new AccountPopup(params, callback), button[0])
            popup.addExtendedClass('account-menu-popup')
            popup.show()
        button.click(callback)
    
    render: (container, params) ->
        content = renderButton()
        container = $(container)
        container.empty().append(content)
        @_initButton(container, params)

module.exports = {AccountMenu}
