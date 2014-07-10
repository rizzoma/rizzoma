###
Сообщение о выходе из риззомы.
###
ck = window.CoffeeKup
localStorage = require('../../utils/localStorage').LocalStorage
History = require('../../utils/history_navigation')
social = require('../../utils/social')

tmpl = ->
    div '.js-log-out-container.log-out-container', ->
        div '.notification-overlay', ''
        div '.notification-block', ->
            div '', ->
                div '.main-block', ->
                    h3 '.logging-out-caption', 'Signing out...'
                    h3 '.logged-out-caption', 'Successfully signed out'
                    if @source is 'google'
                        a '.js-sign-out-from-social.sign-out-from-social', {href: 'https://accounts.google.com/Logout', target: '_blank'}, 'Sign out from Google account'
                    else if @source is 'facebook'
                        a '.js-sign-out-from-social.sign-out-from-social', {href: 'https://facebook.com/', target: '_blank'}, 'Sign out from Facebook account'
                    div '.delimiter', ''
                    h3 '.logged-out-caption.visit-again-caption', 'Visit us again'
                    div '.buttons-container', ->
                        a '.js-enter-rizzoma-btn.btn.sign-in-btn', { href: "/topic/", title: "Sign in"}
                    div '.links-container', ->
                        a href: '/?from=signout_form', 'Home page'
                        a href: 'http://blog.rizzoma.com/?from=signout_form', 'Blog'
                        a href: 'https://rizzoma.com/help-center-faq.html?from=signout_form', 'Help'
                div '.social-block', ->
                    div '.facebook-like', ->
                        text '<fb:like href="http://facebook.com/rizzomacom" send="false" width="270" show_faces="true"></fb:like>'
                    div '.google-plus-like', ->
                        div '.g-plusone', {'data-href': 'http://rizzoma.com', 'data-callback': 'logoutPlusoneCallback'}, ''


showMessage = ->
    window.logoutPlusoneCallback = (param) ->
        _gaq.push(['_trackEvent', 'Social', '+1', 'Signout form']) if param.state == "on"
    social.addPlusoneScript()
    window.fbAsyncInit = ->
        FB.Event.subscribe('edge.create', (targetUrl) ->
            _gaq.push(['_trackSocial', 'facebook', 'Like', targetUrl])
            _gaq.push(['_trackEvent', 'Social', 'Like', 'Signout form'])
        )
    social.addFacebookScript()
    body = $(document.body).append(ck.render(tmpl, {source: window?.userInfo?.authSource, redirectUrl: History.getLoginRedirectUrl()}))
    container = body.find('.js-log-out-container')
    container.show()
    link = body.find('.js-sign-out-from-social')
    link.on 'click', (e) ->
        _gaq.push(['_trackEvent', 'Authorization', 'Sign out from social', link.text()])
    body.find('.js-enter-rizzoma-btn').click (e) ->
        _gaq.push(['_trackEvent', 'Authorization', 'Sign in again click', window.location.pathname])
        window.AuthDialog.initAndShow(false, History.getLoginRedirectUrl())
        container.hide()
        e.stopPropagation()
        e.preventDefault()


showSuccessfullyLoggedOut = ->
    $('.js-log-out-container').addClass('logged-out')

logOut = ->
    _gaq.push(['_trackEvent', 'Authorization', 'Sign out from Rizzoma'])
    localStorage.clear()
    return window.androidJSInterface.onLogout() if window.androidJSInterface
    showMessage()
    if FB?
        FB?.init({
            appId  : '267439770022011',
            status : true, # check login status
            cookie : true, # enable cookies to allow the server to access the session
            xfbml  : true  # parse XFBML
        })
    $.ajax('/logout/', {complete: showSuccessfullyLoggedOut})


module.exports = {logOut}