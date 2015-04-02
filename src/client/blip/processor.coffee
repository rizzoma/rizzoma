{BlipProcessorBase} = require('./processor_base')
{BlipViewModel} = require('./')
{PlaybackBlipViewModel} = require('../playback/blip_view_model')
{PlaybackWaveViewModel} = require('../playback/wave_view_model')
{Request} = require('../../share/communication')

class BlipProcessor extends BlipProcessorBase

    __constructBlip: (blipData, waveViewModel, container, parentBlip) ->
        ###
        @override
        ###
        isPlaybackMode = waveViewModel instanceof PlaybackWaveViewModel
        BlipViewModelClass = if isPlaybackMode then PlaybackBlipViewModel else BlipViewModel
        viewModel = super(blipData, waveViewModel, container, parentBlip, BlipViewModelClass)
        if isPlaybackMode
            viewModel.getModel().appendOps(blipData.meta?.ops)
        return viewModel


    _sendGetBlipRequest: (waveViewModel, request) ->
        isPlaybackMode = waveViewModel instanceof PlaybackWaveViewModel
        if isPlaybackMode
            @_rootRouter.handle('network.playback.getBlipForPlayback', request)
        else
            super(waveViewModel, request)

    getPlaybackOps: (blipId, offset, callback) ->
        request = new Request({blipId, offset}, (err, ops) =>
            @showPageError(err) if err
            callback(err, ops)
        )
        @_rootRouter.handle('network.playback.getPlaybackOps', request)

module.exports.BlipProcessor = BlipProcessor
module.exports.instance = null
