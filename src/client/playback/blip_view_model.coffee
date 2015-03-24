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
        @_model.forward()

    back: () ->
        offset = @_model.back()
        return if offset < 0
        @_blipProcessor.getPlaybackOps(@_model.getServerId(), offset, (err, ops) =>
            return if err
            @appendOps(ops)
            @back()
        )


    getOriginalBlip: () ->
        return @_waveViewModel.getOriginalBlip(@getServerId())

module.exports = {PlaybackBlipViewModel}
