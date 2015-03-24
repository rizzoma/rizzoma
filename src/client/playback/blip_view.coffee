{BlipView} = require('../blip/view')
{PlaybackInteractor} = require('./interactor')
DOM = require('../utils/dom')

class PlaybackBlipView extends BlipView

    _initBlipEventsInteractor: () ->
        @_interactor = new PlaybackInteractor(@_blipViewModel, @)

    markAsPlaybackRoot: () ->
        @_isPlaybackRoot = yes

    attachPlaybackRootMenu: (menu) ->
        return if not @_isPlaybackRoot
        @_interactor.attachMenu(menu, @_menuContainer, {})
        DOM.addClass(@_menuContainer, 'active')

    markActive: ->
        return if @_isPlaybackRoot
        super()

    unmarkActive: ->
        return if @_isPlaybackRoot
        super()

module.exports = {PlaybackBlipView}
