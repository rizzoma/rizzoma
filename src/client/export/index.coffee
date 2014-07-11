{renderCommonForm, renderArchiveList} = require('./template')
{popup} = require('../popup')
{PopupContent} = require('../popup')
{Request} = require('../../share/communication')
processor = require('./processor').instance

class ExportPopup extends PopupContent

    ARCHIVE_LIST_UPDATE_INTERVAL: 10
    
    constructor: (topics) ->
        @_archives = []
        @_container = $(renderCommonForm({topics: topics}))[0]
        @_addClickHandler()
        @_loadArchiveList()
        @_interval = setInterval( =>
            @_loadArchiveList()
        , @ARCHIVE_LIST_UPDATE_INTERVAL * 1000)
    
    _onSelectAllClick: (container, element) ->
        container.find(':checkbox').attr('checked', element.is(':checked'))

    _getWaveIdsToExport: (container) ->
        ids = []
        items = container.find('.ep-topic :checkbox:checked').parents('.ep-topic')
        $.each(items, (_, item) ->
            ids.push($(item).data('id'))
        )
        return ids
        
    _onStartExportClick: (container) ->
        waveIds = @_getWaveIdsToExport(container)
        return if not waveIds.length
        processor.exportTopics(waveIds, (error) =>
            return if error
            @_renderArchiveList(true, @_archives)
        )
        
    _addClickHandler: ->
        container = $(@_container)
        container.click((event) =>
            element = $(event.target)
            if element.hasClass('ep-select-all')
                @_onSelectAllClick(container, element)
            if element.hasClass('ep-start')
                @_onStartExportClick(container)
        )
        
    _renderArchiveList: (hasTask, archives) ->
        return if not @_container
        container = $(@_container).find('.ep-archives-container')
        container.find('.ep-archives').remove()
        archives = if hasTask then archives[0..1] else archives[0..2]
        @_archives = archives
        if not hasTask and not archives.length
            return container.hide()
        else
            container.show()
        list = renderArchiveList(
            hasTask: hasTask
            archives: archives
        )
        container.append(list)
        
    _loadArchiveList: ->
        processor.findArchives((error, data) =>
            return if error
            @_renderArchiveList(data.hasTask, data.archives)
        )

    destroy: ->
        container = $(@_container)
        container.unbind()
        container.remove()
        @_container = null
        clearInterval(@_interval) 
        
    getContainer: ->
        return @_container

exports.showExportPopup = (topics, node) ->
    popup.hide()
    popup.render(new ExportPopup(topics), node)
    popup.show()
