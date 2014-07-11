BlipViewModelBase = require('./index_base')
{BlipView} = require('./view')

class BlipViewModel extends BlipViewModelBase
    __initView: (waveViewModel, blipProcessor, model, timestamp, container, parentBlip, isRead) ->
        @__view = new BlipView(waveViewModel, blipProcessor, @, model, timestamp, container, parentBlip, isRead)

exports.BlipViewModel = BlipViewModel
