{BlipView} = require('../blip/view')
{PlaybackInteractor} = require('./interactor')

class PlaybackBlipView extends BlipView

    _initBlipEventsInteractor: () ->
        @_interactor = new PlaybackInteractor(@_blipViewModel, @)


module.exports = {PlaybackBlipView}
