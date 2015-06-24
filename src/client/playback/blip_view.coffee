{BlipView} = require('../blip/view')
{PlaybackInteractor} = require('./interactor')
DOM = require('../utils/dom')

class PlaybackBlipView extends BlipView

    _addRootBlipClasses: () ->
        DOM.addClass(@_blipContainer, 'root-blip')

    _initBlipEventsInteractor: () ->
        @_interactor = new PlaybackInteractor(@_blipViewModel, @)

    _isFolded: (args...) ->
        return false if @isRoot()
        return super(args...)

    attachPlaybackRootMenu: (menu) ->
        return if not @isRoot()
        @_interactor.attachMenu(menu, @_menuContainer, {})
        DOM.addClass(@_menuContainer, 'active')

    setReadState: () ->

    markActive: ->
        return if @isRoot()
        super()

    unmarkActive: ->
        return if @isRoot()
        super()

    setCalendarDate: (date) ->
        @_interactor?.setCalendarDate(date)

    setCalendarDateIfGreater: (date) ->
        @_interactor?.setCalendarDateIfGreater(date)

    showOperationLoadingSpinner: () ->
        @_interactor?.showOperationLoadingSpinner()

    hideOperationLoadingSpinner: () ->
        @_interactor?.hideOperationLoadingSpinner()

    switchForwardButtonsState: (isDisable) ->
        @_interactor?.switchForwardButtonsState(isDisable)

    switchBackButtonsState: (isDisable) ->
        @_interactor?.switchBackButtonsState(isDisable)

module.exports = {PlaybackBlipView}
