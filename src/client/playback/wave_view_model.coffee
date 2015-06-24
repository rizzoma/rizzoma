{WaveViewModel} = require('../wave/index')
{PlaybackBlipMenu} = require('./blip_menu')
{PlaybackWaveView} = require('./wave_view')
async = require('async')
_ = require('underscore')

DIRECTION_FORWARD = 1
DIRECTION_BACK = 2

class PlaybackWaveViewModel extends WaveViewModel

    constructor: (args..., @_originalWaveViewModel, @_rootBlipId) ->
        super(args...)
        @_blipMenu = new PlaybackBlipMenu()

    __initView: (processor, participants, container) ->
        @__view = new PlaybackWaveView(@, processor, participants, container, @_originalWaveViewModel.getView(), @_rootBlipId)

    _subscribe: () ->

    _subscribeBlip: (blip) ->

    getOriginalBlip: (id) ->
        return @_originalWaveViewModel.getBlipByServerId(id)

    setBlipAsLoaded: (blip) ->
        super(blip)
        view = blip.getView()
        if view.isRoot()
            view.attachPlaybackRootMenu(new PlaybackBlipMenu({isRoot: true}))
            view.setCursor()
            view.setCursorToStart()
            @getView().runCheckRange()
            @_rootBlipView = view
            @_originalWaveViewModel.getView().unlinkActiveBlip()
        @_initRootBlipCalendar()

    _initRootBlipCalendar: () =>
        return if not @_rootBlipView
        for own id, blip of @_loadedBlips
            @_rootBlipView.setCalendarDateIfGreater(blip.getModel().getLastOpDate())

    getRootBlipView: () ->
        return @_rootBlipView

    forward: () ->
        @_oneOp(DIRECTION_FORWARD)

    back: () ->
        @_oneOp(DIRECTION_BACK)

    _oneOp: (direction) ->
        @_discover(direction, (err, ops) =>
            [ts, id] = ops[0]
            if direction == DIRECTION_FORWARD
                @_loadedBlips[id].executeOneForwardOp()
            else
                @_loadedBlips[id].executeOneBackOp()
        )

    fastForward: () ->
        @_fast(DIRECTION_FORWARD)

    fastBack: () ->
        @_fast(DIRECTION_BACK)

    _fast: (direction) ->
        @_discover(direction, (err, ops) =>
            [ts, id] = ops[1]
            date = new Date(ts*1000)
            [ts, id] = ops[0]
            if direction == DIRECTION_FORWARD
                @_loadedBlips[id].executeFastForward(date)
            else
                @_loadedBlips[id].executeFastBack(date)
        )

    playToDate: (date) ->
        for own id, blip of @_loadedBlips
            blip.playToDate(date)

    _discover: (direction, callback) ->
        infinityValue = if direction==DIRECTION_FORWARD then Infinity else -Infinity
        iterator = (blip, callback) ->
            discoverFunc = if direction==DIRECTION_FORWARD then blip.discoverForward else blip.discoverBack
            discoverFunc(null, (err, nextStepErr, op) ->
                ts = if err then infinityValue else op.meta.ts
                callback(null, [ts, blip.getServerId()])
            )
        async.map(_.values(@_loadedBlips), iterator, (err, ops) ->
            if direction==DIRECTION_FORWARD
                sortFunc = (x, y) -> x[0] - y[0]
            else
                sortFunc = (x, y) -> y[0] - x[0]
            callback(null, ops.sort(sortFunc))
        )


exports.PlaybackWaveViewModel = PlaybackWaveViewModel
