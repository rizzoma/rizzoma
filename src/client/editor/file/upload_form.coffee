renderUploadForm = require('./template').renderUploadForm
renderUploadFormModal = require('./template').renderUploadFormModal
CenteredWindow = require('../../widget/window/centered_window').CenteredWindow
ModalWindow = require('../../widget/window/modal_window').ModalWindow
WarnWindow = require('../../widget/window/warning')
DomUtils = require('../../utils/dom')
MicroEvent = require('../../utils/microevent')
KeyCodes = require('../../utils/key_codes').KeyCodes
FileError = require('../../../share/file').Error
fileProcessor = null
{MAX_URL_LENGTH} = require('../common')
getFileProcessor = ->
    fileProcessor ||= require('../../file/processor').instance

MAX_FILE_SIZE = 10 * 1024 * 1024 - 1024 * 10

getPrettySizeString = (size) ->
    sizes = ['B', 'KB', 'MB', 'GB', 'TB']
    index = 0
    while size > 1000 and index < sizes.length - 1
        size /= 1024
        index += 1
    return "#{size.toFixed(1)} #{sizes[index]}"

class UploadFormModal extends ModalWindow
    constructor: (fileName) ->
        params =
            title: 'Uploading File'
            closeButton: yes
            onClose: @_onClose
            fileName: fileName
        super(params)

    __createDom: (params) ->
        super(params)
        content = document.createElement('h1')
        content.textContent = "File: '#{params.fileName}' is uploading"
        @setContent(content)

    _onClose: =>
        if window.confirm('Are you sure you want to cancel uploading?')
            @emit('cancel')
            yes
        no

    destroy: ->
        super()
        @removeListeners('cancel')

class UploadLimitExceededErrorFormModal extends ModalWindow
    constructor: ->
        params =
            title: 'Error'
            closeButton: yes
        super(params)

    showMessage: (msg) ->
        @setContent("<h1>#{msg} <a href=\"https://rizzoma.com/topic/c9a2f62e63536a0fb0ed5b6681c195d4/\" target=\"_blank\">Get more space</a></h1><div style=\"text-align: center;\"><button id=\"uploadLimitExceededErrorCloseBtn\" class=\"button\">Close</button></div>")
        $(@getBodyEl()).find('#uploadLimitExceededErrorCloseBtn').on 'click', =>
            @close()
            @destroy()
        @open()

MicroEvent.mixin(UploadFormModal)

class UploadForm extends CenteredWindow
    constructor: ->
        params =
            title: 'Insert attachment'
            closeButton: yes
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    __createDom: (params) ->
        super(params)
        tmp = document.createElement('span')
        $(tmp).append(renderUploadForm())
        @_body.appendChild(tmp.firstChild)
        $c = $(@_body)
        @_submitButton = $c.find('.js-upload-form-submit')[0]
        @_urlInput = $c.find('#insertAttachmentInput').bind('keypress', @_processUrlInputKeyPressEvent)[0]
        $c.find('.js-insert-attachment-button').click(@_insertAsAttachment)
        @_idInput = $c.find('.js-upload-form-id-input')[0]
        @_browseButton = $c.find('.js-browse-button').bind('click', => @_fileInput.click())[0]
        @_fileLabel = $c.find('.js-upload-form-file-label')[0]
        @_$imageInsertContainer = $c.find('.js-image-insert-container')
        @_$form = $c.find('#uploadForm')
        @_fileInput = $c.find('.js-upload-form-file-input').bind('change', @_submitForm)[0]
        @_uploadQuota = $c.find('.js-upload-quota')[0]

    _submitForm: (file) =>
        @_$form.ajaxSubmit
            url: '/files/'
            dataType: 'json'
            beforeSubmit: (arr) =>
                if arr.length is 1
                    if arr[0].name is 'id' and arr[0].value? and file
                        arr.unshift({name: 'file', value: file})
                    else
                        return false
                else if arr.length is 2
                    return false if not arr[0].value or not arr[1].value
                else
                    files = []
                    for a in arr
                        files.push(a.value) if a.name and a.name is 'file' and a.value
                    @openImmediateUpload(@_editor, files, @_callback)
                    delete @_callback
                    return false
                file = arr[0].value
                fileSize = file.size
                if fileSize > MAX_FILE_SIZE
                    alert "Your file #{file.name || ''} is too large (Max file size: 10 MB)"
                    return false
                @close(no)
                @_modalWindow = new UploadFormModal(file.name || '#file')
                @_modalWindow.on 'cancel', =>
                    @_xhr?.abort()
                    @close()
                @_modalWindow.open()
            beforeSend: (@_xhr) =>
            uploadProgress: (event, position, total, percentComplete) ->
#                    console.log(event, position, total, percentComplete)
            error: (data) =>
                @_renderError(data)
            success: (data) =>
                return @_renderError(data.error) if data.error
                @_editor.insertFile(data.res)
                @close()

    _insertAsAttachment: =>
        url = @_urlInput.value
        return unless url
        return new WarnWindow('Your URL is too long') if url.length > MAX_URL_LENGTH
        @_editor.insertAttachment(url)
        @close()

    _processUrlInputKeyPressEvent: (event) =>
        if event.keyCode is KeyCodes.KEY_ENTER
            @_insertAsAttachment()
            event.preventDefault()
            event.stopPropagation()

    _renderError: (err) ->
        @close()
        return if err?.statusText is 'abort'
        console.error(err)
        if typeof err is 'string'
            msg = err
        else if err.msg?
            msg = err.msg
        else if err.message?
          msg = err.message
        else msg = '_renderError (UF)'
        _gaq.push(['_trackEvent', 'Error', '    Client error', msg])
        if err.code is FileError.FILE_UPLOAD_LIMIT_EXCEEDED_ERROR
            errorWnd = new UploadLimitExceededErrorFormModal()
            return errorWnd.showMessage(err.msg)
        return alert(err) if typeof err is 'string'
        alert('Error occurred. Please try again later.')

    _clear: ->
        @_urlInput.value = ''
        @_$form.resetForm()
        
    _updateQuota: ->
        @_uploadQuota.textContent = 'Retrieving remaining space'
        success = (data, textStatus, jqXHR) =>
            if data.error?
                console.warn(data)
                return error() 
            @_uploadQuota.textContent = "You upload quota is approximately: #{getPrettySizeString(data.res)}" 
            delete @_quotaXhr
        error = (xhr, textStatus, errorThrown) =>
            console.error(xhr, textStatus, errorThrown)
            @_uploadQuota.textContent = 'Failed to get remaining space'
            delete @_quotaXhr
        settings =
            url: '/files/getremainingspace/'
            type: "GET",
            dataType: "json"
            error: error
            success: success
        @_quotaXhr = $.ajax(settings)

    close: (deleteEditor = yes) ->
        if @_quotaXhr
            @_quotaXhr.abort()
            delete @_quotaXhr
        if @_modalWindow
            @_modalWindow.destroy()
            delete @_modalWindow
        if deleteEditor and @_editor
            delete @_editor
            if @_callback
                @_callback()
                delete @_callback
        super()

    openImmediateUpload: (editor, files, callback) ->
        i = 0
        doIteration = =>
            @_editor = editor
            @removeListener('close', doIteration)
            return callback() if i >= files.length
            @_clear()
            getFileProcessor().getRandomId (id) =>
                @_idInput.value = id
            setTimeout =>
                file = files[i]
                @_submitForm(file)
                i += 1
                @on('close', doIteration)
            , 10
        doIteration()

    open: (@_editor, insertImage, @_callback) ->
        super()
        @_clear()
        @_updateQuota()
        if insertImage
            @_$imageInsertContainer.show()
            @_fileLabel.textContent = 'Or upload picture from your computer'
            @_urlInput.focus()
        else
            @_$imageInsertContainer.hide()
            @_fileLabel.textContent = 'Upload file from your computer'
            @_browseButton.focus()
        getFileProcessor().getRandomId (id) =>
            @_idInput.value = id
        @

exports.UploadForm = UploadForm
instance = null

exports.getInstance = ->
    instance ||= new UploadForm()

exports.removeInstance = ->
    instance?.destroy()
    instance = null