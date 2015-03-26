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

    forward: (date) ->
        [isEnd, ts] = @_model.forward()
        view = @getView()
        view.switchForwardButtonsState(yes) if isEnd
        view.setCalendarDate(new Date(ts*1000))
        if date and date > @_model.getCurrentDate() and not isEnd
            @forward(date)

    back: (date) ->
        [offset, ts] = @_model.back()
        view = @getView()
        view.switchForwardButtonsState(no)
        view.setCalendarDate(new Date(ts*1000))
        if offset < 0
            @back(date) if date and date < @_model.getCurrentDate()
            return
        view.showOperationLoadingSpinner()
        @_blipProcessor.getPlaybackOps(@_model.getServerId(), offset, (err, ops) =>
            return if err
            @appendOps(ops)
            @back(date)
            view.hideOperationLoadingSpinner()
        )

    setToDate: (date) ->
        if date > @_model.getCurrentDate()
            @forward(date)
        else
            @back(date)

    getOriginalBlip: () ->
        return @_waveViewModel.getOriginalBlip(@getServerId())

module.exports = {PlaybackBlipViewModel}
