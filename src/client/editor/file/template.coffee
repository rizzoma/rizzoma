ck = window.CoffeeKup

uploadFormTmpl = ->
    div 'file-window-body', ->
        div 'js-image-insert-container', ->
            div ->
                div style: 'padding-bottom: 5px;', ->
                    label {for: 'insertAttachmentInput'}, 'Insert URL of picture on other site'
                div style: 'position: relative;', ->
                    input '.outer-input', {id: 'insertAttachmentInput', type: 'text'}
                    button '.js-insert-attachment-button.inner-button', type: 'button', ' Insert '
            div style: 'height: 1px; margin: 10px 0; background: rgba(0, 0, 0, 0.25);'
        div ->
            form 'upload-form centered', {method: 'post', action: '#', enctype: 'multipart/form-data', id: 'uploadForm', style: 'position: relative;'}, ->
                label 'js-upload-form-file-label', {for: 'uploadFormFileInput'}
                input 'js-upload-form-file-input.file-input', {type: 'file', name: 'file', id: 'uploadFormFileInput', multiple: yes}
                button 'js-browse-button.button.browse-button', type: 'button', 'Browse'
                input 'js-upload-form-id-input', {type: 'hidden', name: 'id'}
            div 'upload-quota centered', ->
                span 'js-upload-quota', ''
                a {href: 'https://rizzoma.com/topic/c9a2f62e63536a0fb0ed5b6681c195d4/', target: '_blank'}, 'Get more space'
            div 'You can also drag & drop files from your desktop'

uploadFormModalTmpl = ->
    div 'upload-form-modal', ->
        div "Loading file \"#{h(@file)}\""
        div '.progress'
        div style: 'test-align: center; margin-top: 10px;', ->
            button '.js-cancel-button.button', 'Cancel'

imgTmpl = ->
    div '.file-content', ->
        a {href: h(@link), target: '_blank', rel: h(@rel)}, ->
            img '.file-preview', {src: h(@thumbnail), alt: h(@name)}
        div '.caption', ->
            a {href: h(@link), target: '_blank'}, h(@name) || 'File'


fileTmpl = ->
    div '.file-content', ->
        div '.file-preview', ->
            h2 '.file-ext', h(@name.substr(@name.lastIndexOf('.'))) || 'File'
        div '.caption', ->
            a {href: h(@link), target: '_blank'}, h(@name) || 'File'

previewableFileTmpl = ->
    div '.file-content', ->
        div '.file-preview', ->
            h2 '.file-ext', h(@name.substr(@name.lastIndexOf('.'))) || 'File'
            div '.caption', ->
                a '.js-view', {href: '#'}, h(@viewText)
        div '.caption', ->
            a {href: h(@link), target: '_blank'}, h(@name) || 'File'

processingFileTmpl = ->
    div '.file-content', style: "background: green;", 'Processing'

errorFileTmpl = ->
    div '.file-content', style:"background: red;", 'Error'

uploadingFileTmpl = ->
    div '.file-content', style: "background: yellow;", 'Uploading'

loadingFileTmpl = ->
    div '.file-content', 'Loading'

module.exports =
    renderUploadForm: ck.compile(uploadFormTmpl)
    renderUploadFormModal: ck.compile(uploadFormModalTmpl)
    renderFile: ck.compile(fileTmpl)
    renderPreviewableFile: ck.compile(previewableFileTmpl)
    renderImage: ck.compile(imgTmpl)
    renderProcessingFile: ck.compile(processingFileTmpl)
    renderErrorFile: ck.compile(errorFileTmpl)
    renderUploadingFile: ck.compile(uploadingFileTmpl)
    renderLoadingFile: ck.compile(loadingFileTmpl)
