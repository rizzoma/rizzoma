{BlipViewModel} = require('../blip')
{PlaybackBlipView} = require('./blip_view')
{PlaybackBlipModel} = require('./blip_model')

class PlaybackBlipViewModel extends BlipViewModel
    __initView: (waveViewModel, blipProcessor, model, timestamp, container, parentBlip, isRead) ->
        @__view = new PlaybackBlipView(waveViewModel, blipProcessor, @, model, timestamp, container, parentBlip, isRead)

    _initModel: (blipData, waveId, isRead, title) ->
        @__model = @_model = new PlaybackBlipModel(blipData, waveId, isRead, title)

    appendOps: (ops) ->
        @_model.appendOps(ops or [])

    forward: () ->
        @_model.forward()

    back: () ->
        @_model.back()

module.exports = {PlaybackBlipViewModel}
