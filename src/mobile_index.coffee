# Hacks block
popup = require('./client/popup').popup
require('./client/popup/user_popup').setUserPopupBehaviour = (node, UserPopupClass, args...) ->
    timeout = null
    delay = 500
    $(node).bind 'click', (event) ->
        if timeout?
            clearTimeout(timeout)
            timeout = null
        popup.hide()
        popup.render(new UserPopupClass(args...), event.target)
        popup.show()
        return false
# End Hacks block

window.cleanupAnalytics = ->
    # Убираем из адреса параметры аналитики
    try
        require('./client/utils/history_navigation').removeAnalytics()
    catch e

start = require('./client/mobile_app').startApp

startApp = ->
    window.removeEventListener('load', startApp, false)
    # forcing browsers to hide loading bar
    setTimeout ->
        window.scrollTo(0, 1)
        start()
    , 50

if document and document.body
    startApp()
else
    window.addEventListener('load', startApp, false)
