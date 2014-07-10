{BaseModule} = require('../../share/base_module')
{WaveViewModel} = require('../wave/index')
{Request} = require('../../share/communication')
History = require('../utils/history_navigation')
{WaveWarning} = require('../wave/notification/warning')
{WaveError} = require('../wave/notification/error')
MicroEvent = require('../utils/microevent')
{CollectionPicker} = require('./picker')
{LocalStorage} = require('../utils/localStorage')

render = window.CoffeeKup.compile ->
    div '.collection-container', ->
        div '.js-collection-notifications.collection-notifications', ''
        div '.js-resizer.resizer', {title: "Resize panels"}, ->
            div '', ''
        div '.collection-topic-container', ->
            div '.js-collection-topic-container.collection-topic-container', ''


class Collection extends BaseModule
    constructor: (args...) ->
        super(args...)
        @_waveProcessor = require('../wave/processor').instance
        @_createDOM()
        @_initLinkClick()
        @_initPicker()
        @_initCollectionList()
        @_$notificationsContainer = $('.js-collection-notifications')

    getContainer: -> @_container

    _createDOM: ->
        @_container = $(render())[0]

    _openWave: (waveId) =>
        @_waveProcessor.getWaveWithBlips waveId, (err, waveData, waveBlips, socialSharingUrl) =>
            return @_processOpenWaveErrorResponse(err, waveId) if err
            @_showWave(waveData, waveBlips, socialSharingUrl)

    _processOpenWaveErrorResponse: (err, waveId) ->
        console.error("Could not open collection #{waveId}", err)

    _closeCurWave: ->
        if @_curWave?
            @emit('wave-close', @_curWave)
            @_curWave.getView().removeListener('range-change', @_onCurWaveRangeChange)
        @_curWave?.destroy()
        delete @_curWave
        @emit('wave-change', null)

    _showWave: (waveData, waveBlips, socialSharingUrl) =>
        @_closeCurWave()
        @_curWave = new WaveViewModel(@_waveProcessor, waveData, waveBlips, socialSharingUrl, @)
        listButtonWidth = $(@_picker.getTopicListButton()).outerWidth()
        @_curWave.getView().setReservedHeaderSpace(listButtonWidth + 30)
        @_curWave.getView().on('range-change', @_onCurWaveRangeChange)
        @_picker.getPanel().setActiveItem()
        @emit('wave-change', @_curWave)

    _onCurWaveRangeChange: (range, blipView) =>
        rootBlipId = @_curWave.getModel()?.getRootBlipId()
        blipId =  blipView.getViewModel()?.getModel()?.getServerId()
        if rootBlipId and blipId and rootBlipId == blipId
            @_picker.hideTopicsWarning()
        else
            @_picker.showTopicsWarning()

    getWaveContainer: -> $(@_container).find('.js-collection-topic-container')[0]

    _initCollectionList: ->
        processTopicsLoaded = (haveCollectionTopics) =>
            if haveCollectionTopics
                @_addToNavigationPanel()
                @_picker.removeListener('collection-inited', processTopicsLoaded)
                require('../account_setup_wizard/processor').instance.changeBusinessType(true)
        @_picker.on('collection-inited', processTopicsLoaded)

    _addToNavigationPanel: ->
        request = new Request({container: @_container}, ->)
        @_rootRouter.handle('navigation.addCollection', request)

    _initLinkClick: ->
        # Обработка клика на ссылку в коллекции
        # Навешиваем обработчики на родительскую ноду контейнера, т.к. на самом контейнере выполняется .empty(),
        # которое снимает все обработчики
        $eventContainer = $(@getWaveContainer().parentNode)
        $eventContainer.on 'mousedown', 'a', (event) ->
            # Не устанавливаем курсор при клике на ссылку
            event.preventDefault()
        $eventContainer.on 'click', 'a', (event) ->
            return if event.which not in [1, 2]
            editorParent = $(event.target).parent().parent('.js-editor')
            return if editorParent.length == 0 # ссылка не в редакторе
            urlParams = History.getUrlParams(event.currentTarget.href)
            if urlParams.host and urlParams.waveId
                History.navigateTo(urlParams.waveId, urlParams.serverBlipId)
            else
                # Клик в редактируемой области по умолчанию не открыает ссылку, поэтому сделаем это за браузер
                window.open(event.currentTarget.href, '_blank')
            event.preventDefault()
            event.stopPropagation()
        $eventContainer.on 'click', '.js-topic-url', (event) ->
            return if event.which isnt 1 or event.ctrlKey or event.metaKey
            urlParams = History.getUrlParams(event.currentTarget.href)
            History.navigateTo(urlParams.waveId, urlParams.serverBlipId)
            event.preventDefault()
            event.stopPropagation()

    _initPicker: ->
        @_picker = new CollectionPicker(@)
        @_container.appendChild(@_picker.getTopicListButton())
        @_container.appendChild(@_picker.getTopicsWarning())
        @_container.appendChild(@_picker.getTopicListContainer())
        @_picker.on 'topic-change', (topicId) =>
            LocalStorage.setLastCollectionTopicId(topicId)
            @_openWave(topicId)

    showWaveWarning: (message) ->
        ###
        Показывает предупреждение, связанное с волной
        @param err: object
        ###
        warnings = @_$notificationsContainer.find('.js-wave-warning')
        $(warnings[0]).remove() if warnings.length >= 5
        @_$notificationsContainer.append(new WaveWarning(message).getContainer())
        console.warn('Wave warning occurred in collection')
        console.warn(message)

    showWaveError: (err) ->
        ###
        Показывает ошибку, связанную с волной
        @param err: object
        ###
        waveError = new WaveError(err)
        errors = @_$notificationsContainer.find('.js-wave-error')
        $(errors[0]).remove() if errors.length >= 5
        @_$notificationsContainer.append(waveError.getContainer())
        console.error("Wave error occurred in collection")
        console.error(err.stack)

    load: (request) ->
        # Навигационная панель вызывает при первом открытии таба с коллекцией
        return if @_loaded
        @_loaded = true
        lastTopicId = LocalStorage.getLastCollectionTopicId()
        if !lastTopicId || !@_picker.hasTopicIdInList(lastTopicId)
            lastTopicId = @_picker.getFirstTopicIdInList()
            LocalStorage.setLastCollectionTopicId(lastTopicId)
        @_openWave(lastTopicId)

    getCurrentWave: -> @_curWave


MicroEvent.mixin(Collection)
module.exports.Collection = Collection
