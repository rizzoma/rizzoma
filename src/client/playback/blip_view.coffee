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
        date = @_model.getLastOpDate()
        @_interactor.setCalendarDate(date) if date

    markActive: ->
        return if @_isPlaybackRoot
        super()

    unmarkActive: ->
        return if @_isPlaybackRoot
        super()

    setCalendarDate: (date) ->
        @_interactor.setCalendarDate(date)

    showOperationLoadingSpinner: () ->
        @_interactor.showOperationLoadingSpinner()

    hideOperationLoadingSpinner: () ->
        @_interactor.hideOperationLoadingSpinner()

    switchForwardButtonsState: (isDisable) ->
        @_interactor.switchForwardButtonsState(isDisable)

module.exports = {PlaybackBlipView}
