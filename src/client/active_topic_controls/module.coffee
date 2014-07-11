###
Модуль отвечает за работу кнопок активного топика: следующий прочитанный, прочитать все, свернуть/развернуть все,
кнопки для вставки mention'ов, блипов, гаджетов и т.п.
Следит за текущим положением курсора, обновляет состояние меню в соотетствии с курсором, выбранное действие
применяет к тому топику, в котором стоит курсор. Если курсор не находится в топике, применяет действие к топику из
WaveModule.
Для работы опрашивает модули, у которых может находится топик, следит за изменением топиков в этих модулях через
событие wave-change.
Первый запрос топика делается методов getCurrentWave.
###

{BaseModule} = require('../../share/base_module')
{InsertGadgetPopup} = require('../wave/insert_gadget_popup')
History = require('../utils/history_navigation')
BrowserSupport = require('../utils/browser_support')
DomUtils = require('../utils/dom')

# Список всех модулей, за топиками которых нужно следить
TOPIC_MODULES = [
    {
        name: 'collection'
        path: '../collection/module'
    },
    {
        name: 'topic'
        path: '../modules/wave'
    }
]
# Ключ топика, который будет использоваться, если курсор не находится ни в одном из топиков
DEFAULT_TOPIC_NAME = 'topic'

# Выключает стандартную обработку события mousedown для переданных элементов. Нужно, чтобы при нажатии на кнопки
# курсор не изменял своей позиции, т.к. работа большинства кнопок зависит от позиции курсора.
preventElementsMousedown = ($elements) ->
    $elements.mousedown (e) =>
        # Не теряем курсор при обработке нажатия на эти кнопки
        e.preventDefault()

class ActiveTopicControls extends BaseModule
    constructor: (args...) ->
        super(args...)
        @_waveProcessor = require('../wave/processor').instance
        @_initRightToolsPanel()
        @_initTopics()
        $(document).click(@_updateUnreadButtonsState)

    _initTopics: ->
        @_topicInfo = {}
        for {name, path} in TOPIC_MODULES
            module = require(path).instance
            continue if not module
            @_topicInfo[name] =
                topic: null
                unreadCount: 0
            @_updateTopic(name, module.getCurrentWave()) if module.getCurrentWave()?
            # То же самое, что и _.apply(_updateTopic, name)
            module.on 'wave-change', do (name) => (topic) => @_updateTopic(name, topic)

    _updateTopic: (name, topic) ->
        @_topicInfo[name].topic = topic
        @_topicInfo[name].unreadCount = topic?.getUnreadBlipsCount()
        @_updateUnreadButtonsState()
        @_deactivateInsertMenu() if not @_getActiveTopicInfo().topic?
        return if not BrowserSupport.isSupported()
        topic?.on 'unread-blips-count', (count) =>
            @_topicInfo[name].unreadCount = count
            @_updateUnreadButtonsState()

    _getActiveTopicInfo: ->
        for name, topicInfo of @_topicInfo
            return topicInfo if topicInfo.topic?.getView().hasCursor()
        return @_topicInfo[DEFAULT_TOPIC_NAME]

    _initRightToolsPanel: ->
        @_$rightToolsPanel = $('.js-right-tools-panel')
        @_initFoldButtons()
        @_initNextUnreadButton()
        @_initGadgetPopup()
        @_initInsertMenu() if History.isEmbedded()

    _initFoldButtons: ->
        preventElementsMousedown(@_$rightToolsPanel.find('.js-hide-replies, .js-show-replies'))
        @_$rightToolsPanel.find('.js-hide-replies').click =>
            activeWave = @_getActiveTopicInfo().topic
            return if not activeWave?
            activeWave.getView().foldAll().topic
            _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Root menu'])
        @_$rightToolsPanel.find('.js-show-replies').click =>
            activeWave = @_getActiveTopicInfo().topic
            return if not activeWave?
            activeWave.getView().unfoldAll()
            _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Root menu'])

    _initNextUnreadButton: ->
        @_$nextUnreadBlipButton = @_$rightToolsPanel.find('.js-next-unread-blip')
        @_$nextUnreadBlipButton.addClass('disabled')
        preventElementsMousedown(@_$nextUnreadBlipButton)
        $(@_$nextUnreadBlipButton).click(@_goToNextUnreadBlip)

    _goToNextUnreadBlip: =>
        @_getActiveTopicInfo().topic?.goToNextUnreadBlip()

    _updateUnreadButtonsState: (e) =>
        count = @_getActiveTopicInfo().unreadCount
        if not count
            @_$nextUnreadBlipButton.addClass('disabled')
            return if History.isEmbedded()
            return if not e or e.type isnt 'click' or not (e.target is @_$nextUnreadBlipButton[0] or
                    DomUtils.contains(@_$nextUnreadBlipButton[0], e.target))
            $globalNextUnread = $('#global-next-unread')
            return if $globalNextUnread.hasClass('disabled')
            $globalNextUnread.css('display', 'inline-block')
            handleMouseDown = (e) ->
                return if e.target is $globalNextUnread[0]
                $(document).off('mousedown', handleMouseDown)
                $globalNextUnread.css('display', 'none')

            $(document).on('mousedown', handleMouseDown)
        else if @_$nextUnreadBlipButton.hasClass('disabled')
            @_$nextUnreadBlipButton.removeClass('disabled')

    _initGadgetPopup: ->
        $insertGadgetContainer = @_$rightToolsPanel.find('.js-insert-gadget-container')
        $insertGadgetButton = @_$rightToolsPanel.find('.js-insert-gadget')
        $insertGadgetButton[0]?.insertGadgetPopup = new InsertGadgetPopup($insertGadgetContainer, $insertGadgetButton)

    _initInsertMenu: ->
        @_$insertMenuButton = @_$rightToolsPanel.find('.js-insert')
        preventElementsMousedown(@_$insertMenuButton)
        @_$insertMenuButton.click (e) =>
            $group = @_$rightToolsPanel.find('.js-active-blip-controls-group')
            if $group.hasClass('active')
                @_deactivateInsertMenu()
            else
                @_activateInsertMenu()

    _activateInsertMenu: ->
        window.addEventListener('mousedown', @_deactivateInsertMenu, yes)
        @_$rightToolsPanel.find('.js-active-blip-controls-group').addClass('active')

    _deactivateInsertMenu: (e) =>
        return if e and (@_$insertMenuButton[0] is e.target or $.contains(@_$insertMenuButton[0], e.target))
        window.removeEventListener('mousedown', @_deactivateInsertMenu, yes)
        @_$rightToolsPanel.find('.js-active-blip-controls-group').removeClass('active')


module.exports = {ActiveTopicControls}