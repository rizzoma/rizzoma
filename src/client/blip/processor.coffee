{BlipProcessorBase} = require('./processor_base')
{BlipViewModel} = require('./')
{PlaybackBlipViewModel} = require('../playback/blip_view_model')
{PlaybackWaveViewModel} = require('../playback/wave_view_model')

class BlipProcessor extends BlipProcessorBase

    __constructBlip: (blipData, waveViewModel, container, parentBlip) ->
        ###
        @override
        ###
        isPlaybackMode = waveViewModel instanceof PlaybackWaveViewModel
        BlipViewModelClass = if isPlaybackMode then PlaybackBlipViewModel else BlipViewModel
        viewModel = super(blipData, waveViewModel, container, parentBlip, BlipViewModelClass)
        if isPlaybackMode
            viewModel.appendOps(blipData.meta?.ops)
        return viewModel


    _sendGetBlipRequest: (waveViewModel, request) ->
        isPlaybackMode = waveViewModel instanceof PlaybackWaveViewModel
        if isPlaybackMode
            @_rootRouter.handle('network.wave.getBlipForPlayback', request)
        else
            super(waveViewModel, request)

module.exports.BlipProcessor = BlipProcessor
module.exports.instance = null
