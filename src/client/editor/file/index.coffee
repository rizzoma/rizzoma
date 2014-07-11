FileStatus = require('../../../share/file').FileStatus
BrowserSupportedImageTypes = require('../../../share/file').BrowserSupportedImageTypes
renderer = require('./template')
{Viewer, SUPPORTED_TYPES, SUPPORTED_EXTS} = require('./viewer')

class File
    constructor: (args...) ->
       @_init(args...)

    _init: (@_rel, id, @_relUpdateCallback) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        FileProcessor = require('../../file/processor').instance
        FileProcessor.getFileInfo id, @_renderInfo
        @_renderInfo()

    _renderInfo: (info) =>
        $container = $(@_container).empty()
        status = info?.status
        switch status
            when FileStatus.READY
                data = info.data
                showThumbnail = BrowserSupportedImageTypes.indexOf(data.mime) >= 0
                params =
                    name: (name = data.name)
                    link: data.link
                    mime: (fileType = data.mime)
                    size: (fileSize = data.size)
                    userId: data.userId
                if showThumbnail and data.thumbnail
                    params.rel = @_rel
                    params.thumbnail = data.thumbnail
                    $container.append(renderer.renderImage(params))
                    @_relUpdateCallback() if @_relUpdateCallback
                else
                    if (viewer = SUPPORTED_TYPES[fileType])? and viewer.limit >= fileSize or
                            SUPPORTED_EXTS.indexOf(name.substr(name.lastIndexOf('.')).toLowerCase()) != -1 and (viewer = SUPPORTED_EXTS.viewer)?
                        params.viewText = 'View' + viewer.additionalString
                        $container.append(renderer.renderPreviewableFile(params))
                        $container.find('.js-view').on 'click', (e) ->
                            e.preventDefault()
                            e.stopPropagation()
#                            Viewer.open(fileType, 'https://rizzoma.com/r/files/aaf99aba80ea1d7655a56fde048edb2f-5b936d66a3bda63f9e9a2d417e03cd3d-0-0.2848742580972612', name)
                            Viewer.open(fileType, "#{location.protocol}//#{location.host}#{data.link}", name)
                    else
                        $container.append(renderer.renderFile(params))
                delete @_relUpdateCallback if @_relUpdateCallback
                @_container.setAttribute('rzUrl', data.link)
            when FileStatus.ERROR
                $container.append(renderer.renderErrorFile())
                delete @_relUpdateCallback
            when FileStatus.UPLOADING
                $container.append(renderer.renderUploadingFile())
            when FileStatus.PROCESSING
                $container.append(renderer.renderProcessingFile())
            else
                $container.append(renderer.renderLoadingFile())

    getContainer: ->
        return @_container

exports.File = File
