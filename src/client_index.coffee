window.cleanupAnalytics = ->
    # Убираем из адреса параметры аналитики
    try
        require('./client/utils/history_navigation').removeAnalytics()
    catch e

require './client/app'
