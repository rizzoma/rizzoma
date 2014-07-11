ck = window.CoffeeKup

renderSynchronizing = ck.compile( ->
    div '.js-connection-error-container.connection-error-container', ->
        div '.connection-error', ->
            div '.js-reconnect-timer', ->
                span "Reconnect in "
                span '.js-reconnecting-interval.reconnecting-interval', ''
                span " sec. "
                a '.js-reconnect-now.reconnect-now', "Click"
                span " to try now"
            div '.js-reconnecting-text', 'Reconnecting right now...'
)

class SyncBoard

    @get: ->
        @instance ?= new @

    renderAndInitInContainer: (container) ->
        $(@_container).find('.js-connection-error-container').remove() if @_container
        @_container = container
        $(@_container).append(renderSynchronizing())
        @_$errorContainer = $(@_container).find('.js-connection-error-container')
        @_$reconnectTimerText = @_$errorContainer.find('.js-reconnect-timer')
        @_$reconnectingText = @_$errorContainer.find('.js-reconnecting-text')
        @_$reconnectLink = @_$errorContainer.find('.js-reconnect-now')
        @_$reconnectIntervalContainer = @_$errorContainer.find('.js-reconnecting-interval')

    setSecondsLeft: (secondsLeft) ->
        @_$reconnectIntervalContainer.text(secondsLeft)

    setReconnectingText: ->
        @_$reconnectTimerText.hide()
        @_$reconnectingText.show()

    setTimerText: ->
        @_$reconnectTimerText.show()
        @_$reconnectingText.hide()

    show: ->
        @_$errorContainer.addClass('error-shown')
        @setTimerText()

    hide: ->
        @_$errorContainer.removeClass('error-shown')

    getReconnectLink: -> @_$reconnectLink

exports.syncBoardInstance = SyncBoard.get()