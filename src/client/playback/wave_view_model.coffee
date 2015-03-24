{WaveViewModel} = require('../wave/index')
{PlaybackBlipMenu} = require('./blip_menu')
{PlaybackWaveView} = require('./wave_view')

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
        if blip.getServerId() == @_rootBlipId
            view = blip.getView()
            view.markAsPlaybackRoot()
            view.attachPlaybackRootMenu(new PlaybackBlipMenu())
            view.setCursor()
            view.setCursorToStart()
            @getView().runCheckRange()

exports.PlaybackWaveViewModel = PlaybackWaveViewModel
