ModalWindow = require('../../widget/window/modal_window').ModalWindow
DomUtils = require('../../utils/dom')

warningTmpl = ->
    div style: 'font-size: 16px; text-align: center;', ->
        span 'You are going to open file with external service.'
        br ''
        span 'By using this service you acknowledge that you have read and'
        br ''
        span 'agreed to the '
        a {href: 'https://docs.google.com/viewer', target: '_blank'}, 'Google Docs Viewer Terms of Service'
    div style: 'font-size: 13px; color: #818588; text-align: center;', ->
        input {type: 'checkbox', style: 'vertical-align: middle; margin-right: 5px;', id: 'docsViewerDoNotShow'}
        label for: 'docsViewerDoNotShow', "Don't show this warning"
    div {style: 'text-align: center;'}, ->
        button 'button js-open-button', style: 'margin: 5px 15px;', 'Open document'
        button 'button js-cancel-button', style: 'margin: 5px 15px;', 'Cancel'

renderWarnContent = window.CoffeeKup.compile(warningTmpl)

PROP_ID = 'gDocsViewerNoWarn'

class SimpleViewer extends ModalWindow
    open: (url) ->
        super()

class WarnWindow extends ModalWindow
    constructor: ->
        params =
            title: 'Warning'
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    _handleOpenBtn: =>
        @emit('accept')
        @destroy()

    _handleCancelBtn: =>
        _gaq.push(['_trackEvent', 'Topic content', 'Cancel preview attach'])
        @destroy()

    destroy: ->
        @removeAllListeners('accept')
        @_openButton.removeEventListener('click', @_handleOpenBtn, no)
        @_cancelButton.removeEventListener('click', @_handleCancelBtn, no)
        checked = document.getElementById('docsViewerDoNotShow').checked
        prefs = require('../../user/processor').instance?.getMyPrefs()
        if checked and prefs? and prefs[PROP_ID] isnt checked
            prefs[PROP_ID] = checked
            require('../../wave/processor').instance.setUserClientOption(PROP_ID, checked, ->)
        super()

    open: ->
        f = DomUtils.parseFromString(renderWarnContent())
        child = f.firstChild
        @setContent(f)
        parent = child.parentNode
        @_openButton = parent.getElementsByClassName('js-open-button')[0]
        @_cancelButton = parent.getElementsByClassName('js-cancel-button')[0]
        @_openButton.addEventListener('click', @_handleOpenBtn, no)
        @_cancelButton.addEventListener('click', @_handleCancelBtn, no)
        @on 'close', ->
            @destroy()
        super()

class DocsViewer extends SimpleViewer
    constructor: ->
        params =
            title: 'Insert attachment'
            closeButton: yes
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    open: (url, name) ->
        url += "/#{encodeURIComponent(name)}"
        accept = =>
            content = document.createElement('iframe')
            content.src = "https://docs.google.com/viewer?url=#{encodeURIComponent(url)}&embedded=true"
            content.width = '100%'
            content.height = '100%'
            content.style.border = 'none'
            @getBodyEl().style.height = '100%'
            @setContent(content)
            DocsViewer.__super__.open.call(@, url)
        if require('../../user/processor').instance?.getMyPrefs()?[PROP_ID]
            accept()
        else
            wnd = new WarnWindow()
            wnd.on('accept', accept)
            wnd.open()

docsViewer =
    cls: DocsViewer
    limit: 25 * 1024 * 1024
    additionalString: ' in Google Docs'

module.exports.SUPPORTED_EXTS = SUPPORTED_EXTS = exts = [
    '.txt',
    '.css',
    '.html',
    '.php',
    '.c',
    '.cpp',
    '.h',
    '.hpp',
    '.js',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.pdf',
    '.pages',
    '.ai',
    '.psd',
    '.tiff',
    '.dxf',
    '.svg',
    '.eps',
    '.ps',
    '.ttf',
    '.xps',
    '.log'
]

SUPPORTED_EXTS.viewer = docsViewer

module.exports.SUPPORTED_TYPES = SUPPORTED_TYPES =
    'application/javascript': docsViewer
    'application/illustrator': docsViewer
    'application/msword': docsViewer
    'application/oxps': docsViewer
    'application/pdf': docsViewer
    'application/postscript': docsViewer
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': docsViewer
    'application/vnd.ms-excel': docsViewer
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': docsViewer
    'application/vnd.ms-powerpoint': docsViewer
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': docsViewer
    'application/vnd.oasis.opendocument.text': docsViewer
    'application/vnd.oasis.opendocument.presentation': docsViewer
    'application/x-font-ttf': docsViewer
    'application/x-iwork-pages-sffpages': docsViewer
    'image/vnd.adobe.photoshop': docsViewer
    'image/vnd.dxf': docsViewer
    'image/svg+xml': docsViewer
    'image/tiff': docsViewer
    'image/x-eps': docsViewer
    'text/plain': docsViewer
    'text/css': docsViewer
    'text/html': docsViewer
    'text/x-csrc': docsViewer
    'text/x-c++src': docsViewer
    'text/x-chdr': docsViewer
    'text/javascript': docsViewer

class Viewer
    open: (type, url, name) ->
        return unless (viewer = SUPPORTED_TYPES[type] or viewer = SUPPORTED_EXTS.viewer)
        wnd = new viewer.cls()
        style = wnd.getWindow().style
        style.width = '90%'
        style.height = '90%'
        wnd.getBodyEl().style.border = 'none'
        wnd.open(url, name)
        _gaq.push(['_trackEvent', 'Topic content', 'Preview attach', type])
        onClose = ->
            @removeListener('close', onClose)
            @destroy()
        wnd.on('close', onClose)

module.exports.Viewer = new Viewer()
