BrowserEvents = require('../../utils/browser_events')

PlaybackEventTypes =
    CALENDAR: '_calendar'
    FAST_BACK: '_fast_back'
    BACK: '_back'
    FORWARD: '_forward'
    FAST_FORWARD: '_fast_forward'
    COPY: '_copy'
    REPLACE: '_replace'

class EventProcessor

    _calendar: (interactor, args) ->
        interactor.calendar(args.event?.target)

    _fast_back: (interactor) ->
        interactor.fastBack()

    _back: (interactor) ->
        interactor.back()

    _forward: (interactor) ->
        interactor.forward()

    _fast_forward: (interactor) ->
        interactor.fastForward()

    _copy: (interactor) ->
        interactor.copy()

    _replace: (interactor) ->
        interactor.replace()


module.exports =
    PlaybackEventTypes: PlaybackEventTypes
    EventProcessor: new EventProcessor()
