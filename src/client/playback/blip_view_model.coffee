{BlipViewModel} = require('../blip')
{PlaybackBlipView} = require('./blip_view')
{PlaybackBlipModel} = require('./blip_model')

class PlaybackBlipViewModel extends BlipViewModel
    _init: (waveViewModel, @_blipProcessor, blipData, container, parentBlip, isRead, waveId, timestamp, title) ->
        super(waveViewModel, @_blipProcessor, blipData, container, parentBlip, isRead, waveId, timestamp, title)

    __initView: (waveViewModel, blipProcessor, model, timestamp, container, parentBlip, isRead) ->
        @__view = new PlaybackBlipView(waveViewModel, blipProcessor, @, model, timestamp, container, parentBlip, isRead)

    _initModel: (blipData, waveId, isRead, title) ->
        @__model = @_model = new PlaybackBlipModel(blipData, waveId, isRead, title)

    appendOps: (ops) ->
        @_model.appendOps(ops or [])

    forward: () ->
        [isEnd, ts] = @_model.forward()
        view = @getView()
        view.switchForwardButtonsState(yes) if isEnd
        view.setCalendarDate(new Date(ts*1000))

    back: () ->
        [offset, ts] = @_model.back()
        view = @getView()
        view.switchForwardButtonsState(no)
        return view.setCalendarDate(new Date(ts*1000)) if offset < 0
        view.showOperationLoadingSpinner()
        @_blipProcessor.getPlaybackOps(@_model.getServerId(), offset, (err, ops) =>
            return if err
            @appendOps(ops)
            @back()
            view.hideOperationLoadingSpinner()
        )

    getOriginalBlip: () ->
        return @_waveViewModel.getOriginalBlip(@getServerId())

module.exports = {PlaybackBlipViewModel}
