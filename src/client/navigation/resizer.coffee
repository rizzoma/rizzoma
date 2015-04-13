MicroEvent = require('../utils/microevent')

class Resizer

    MIN_NAVIGATION_WIDTH = 317
    CURRENT_WIDTH_COOKIE_NAME = 'navigation-container-width'
    LAST_WIDTH_COOKIE_NAME = 'comfort-navigation-container-width'

    constructor: ->
        @_$tabsContainer = $('.js-tabs-container')
        @_tabsContainerWidth = @_$tabsContainer.width()
        @_toolsPanelWidth = $('.js-right-tools-panel').width()
        @_$wc = $('.js-wave-container')
        @_$nc = $('.js-navigation-container')
        @_$resizer = @_$nc.find('.js-resizer')
        @_$navPanel = @_$nc.find('.js-navigation-panel')
        @_$listsContainer = @_$nc.find('.js-lists-container')
        @_$tipsBox = @_$nc.find('.js-tips-box')
        @_minWaveWidth = parseInt($(document.body).css('min-width')) - MIN_NAVIGATION_WIDTH - @_tabsContainerWidth - @_toolsPanelWidth
        @_resizing = false
        @_startX = null
        @_startWidth = null
        @_lastWidth = null
        setTimeout => # загрузка ширины выполняется аснхронно, чтобы успели проинициализироваться
            @_loadWidth() # обработчики событий activateCurrentTab и deactivateAllTabs
        , 100
        @_register()

    _beginResize: (event) =>
        return if event.which != 1
        event.preventDefault() #условие для пресечения выделения при попытке развернуть панель
        @_resizing = true
        @_startX = event.pageX
        @_startWidth = @_$nc.width()

    _resize: (event) =>
        return if event.which != 1
        if @_resizing
            ncw = @_startWidth + event.pageX - @_startX
            @_resizeTo(ncw)

    _endResize: (event) =>
        return if event.which != 1
        if @_resizing
            @_saveWidth()
        @_resizing = false
        return true

    _resizeTo: (width) ->
        fullWidth = @_$nc.width() + @_$wc.width()
        if width < MIN_NAVIGATION_WIDTH/2
            width = 0
        else if width >= MIN_NAVIGATION_WIDTH/2 && width < MIN_NAVIGATION_WIDTH
            width = MIN_NAVIGATION_WIDTH
        else if fullWidth - width < @_minWaveWidth
            width = fullWidth - @_minWaveWidth
        @_setWidth(width)

    _hideNavPanel: ->
        @_$resizer.hide()
        @_$listsContainer.hide()
        @_$tipsBox.hide()
        @emit 'deactivateAllTabs'

    _showNavPanel: ->
        @_$listsContainer.show()
        @_$tipsBox.show()
        @_$resizer.show()
        @emit 'activateCurrentTab'

    setHalfScreenWidth: () ->
        ncw = (@_$wc.width() + @_$nc.width()) / 2
        @_applyNewWidth(ncw)

    revertToPreviousWidth: () ->
        @_applyNewWidth(@_lastWidth)

    _setWidth: (ncw) ->
        if ncw == 0 and @_lastWidth > 0
            @_hideNavPanel()
        else if ncw >= MIN_NAVIGATION_WIDTH and @_lastWidth <= 0
            @_showNavPanel()
        return if ncw is @_lastWidth
        @_applyNewWidth(ncw)
        @_lastWidth = ncw

    _applyNewWidth: (ncw) ->
        @_$nc.width(ncw)
        @_$navPanel.width(ncw)
        @_setTaskTimeFiltersWidth(ncw)
        @_$wc.css('margin-left', "#{ncw+@_tabsContainerWidth}px")
        $(window).trigger('resizeTopicByResizer')

    _saveWidth: ->
        $.cookie(CURRENT_WIDTH_COOKIE_NAME, @_lastWidth, { path: '/', expires: 7 })

    _loadWidth: ->
        width = parseInt($.cookie(CURRENT_WIDTH_COOKIE_NAME))
        if document.location.pathname == "/topic/" or isNaN(width)
            width = MIN_NAVIGATION_WIDTH if width == 0 or isNaN(width) # isNaN(width) выполняется при заходе без кук ресайзера на /topic/
        if width == 0
            @_lastWidth = MIN_NAVIGATION_WIDTH #инициализируем @_lastWidth для корректной работы @_setWidth
        else
            @_lastWidth = 0
        @_resizeTo(width)

    _setDefaultWidth: (event) =>
        if !event.isTrigger and @_lastWidth > 0
            ncw = @_$nc.width()
            wndWidth = $(window).width()
            limitWidth = @_minWaveWidth + ncw + @_tabsContainerWidth + @_toolsPanelWidth
            difference = limitWidth - wndWidth
            if difference > 0
                ncw = ncw - difference
                ncw = MIN_NAVIGATION_WIDTH if ncw < MIN_NAVIGATION_WIDTH
            @_setWidth(ncw)
            @_saveWidth()

    _register: ->
        @_$nc.on('mousedown', '.js-resizer', @_beginResize)
        @_$nc.on('dblclick', '.js-resizer', @_toggleNavPanel)
        $(window).on('mousemove', @_resize)
        $(window).on('mouseup', @_endResize)
        $(window).on('resize', @_setDefaultWidth)

    _unregister: ->
        @_$nc.off('mousedown', '.js-resizer', @_beginResize)
        @_$nc.off('dblclick', '.js-resizer', @_toggleNavPanel)
        $(window).off('mousemove', @_resize)
        $(window).off('mouseup', @_endResize)
        $(window).off('resize', @_setDefaultWidth)

    _setTaskTimeFiltersWidth: (width) ->
        if width < 364
            $('.js-task-time-filters').addClass('minimal')
        else
            $('.js-task-time-filters').removeClass('minimal')

    _toggleNavPanel: =>
        if @_lastWidth > 0
            @foldNavPanel()
        else if @_lastWidth == 0
            @unfoldNavPanel()

    unfoldNavPanel: ->
        width = parseInt($.cookie(LAST_WIDTH_COOKIE_NAME))
        width = MIN_NAVIGATION_WIDTH if isNaN(width)
        @_resizeTo(width)
        @_saveWidth()

    foldNavPanel: ->
        $.cookie(LAST_WIDTH_COOKIE_NAME, @_lastWidth, { path: '/', expires: 7 })
        @_resizeTo(0)
        @_saveWidth()

    getLastWidth: ->
        @_lastWidth

MicroEvent.mixin(Resizer)
exports.Resizer = Resizer