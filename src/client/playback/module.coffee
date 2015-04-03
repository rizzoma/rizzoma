{BaseModule} = require('../../share/base_module')
{Request} = require('../../share/communication')
{PlaybackWaveViewModel} = require('./wave_view_model')

render = window.CoffeeKup.compile ->
    div '.playback-container search', ->
        div '.js-playback-topic-container.playback-topic-container', ->
            div '.message-container', ->
                div 'Loading playback date'
                div '.wait-icon', {title: 'Loading topic'}

class Playback extends BaseModule
    constructor: (args...) ->
        super(args...)
        @_waveProcessor = require('../wave/processor').instance
        @_createDOM()

    _createDOM: ->
        @_$container = $(render())
        @_container = @_$container[0]
        @_$resizer = $('.js-resizer')

    showPlaybackView: (request) ->
        waveId = request.args.waveId
        blipId = request.args.blipId
        waveViewModel = request.args.waveViewModel
        request = new Request({container: @_container})
        @_rootRouter.handle('navigation.showPlaybackView', request)
        @_$resizer.hide()
        @_waveProcessor.getPlaybackData(waveId, blipId, (err, waveData, waveBlips) =>
            @_$resizer.show().addClass('playback')
            return console.log(err) if err
            @_viewModel = new PlaybackWaveViewModel(@_waveProcessor, waveData, waveBlips, no, @, waveViewModel, blipId)
        )

    hidePlaybackView: (request) ->
        @_viewModel.destroy() if @_viewModel
        delete @_viewModel
        $('.js-resizer').removeClass('playback')

    getWaveContainer: -> $(@_container).find('.js-playback-topic-container')[0]

module.exports.Playback = Playback