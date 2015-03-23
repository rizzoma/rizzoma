{WaveViewModel} = require('../wave/index')
{PlaybackBlipMenu} = require('./blip_menu')
{PlaybackWaveView} = require('./wave_view')

class PlaybackWaveViewModel extends WaveViewModel

    constructor: (args..., @_originalWaveViewModel) ->
        super(args...)
        @_blipMenu = new PlaybackBlipMenu()

    __initView: (processor, participants, container) ->
        @__view = new PlaybackWaveView(@, processor, participants, container)

    _subscribe: () ->

    _subscribeBlip: (blip) ->

    getOriginalBlip: (id) ->
        return @_originalWaveViewModel.getBlipByServerId(id)

exports.PlaybackWaveViewModel = PlaybackWaveViewModel
