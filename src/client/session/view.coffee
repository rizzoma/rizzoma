History = require('../utils/history_navigation')

class SessionViewBase
    hide: ->
    show: ->

class SessionViewMobile extends SessionViewBase        
    constructor: ->
        @_mainContent = document.getElementById('main-content')
        @_sessionView = document.getElementById('session-view')
        window.AuthDialog.init(false, History.getLoginRedirectUrl())
        
    _updateLoginRedirectUrls: ->
        redirectUrl = History.getLoginRedirectUrl()
        window.AuthDialog?.setNext(redirectUrl)

    updateLoginUrls: ->
        @_updateLoginRedirectUrls()

    hide: ->
        @_mainContent.style.display = 'block'
        @_sessionView.style.display = 'none'

    show: ->
        @_updateLoginRedirectUrls()
        window.AuthDialog.show()
        @_mainContent.style.display = 'none'
        @_sessionView.style.display = 'block'

module.exports.SessionViewMobile = new SessionViewMobile()
