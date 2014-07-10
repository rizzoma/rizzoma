ck = window.CoffeeKup

linkEditorTmpl = ->
    div '.link-editor-body', ->
        div style: 'font-size: 14px;', 'Insert link'
        table '.link-editor-content', ->
            tr '.link-name', ->
                td '', 'Text'
                td '', ->
                    label ->
                        input '.js-link-editor-text-input .text-input', {type: 'text'}
                    div '.js-link-editor-text-div', ''
            tr '.link-url', ->
                td '', 'URL'
                td '', ->
                    label ->
                        input '.js-link-editor-url-input .text-input', {type: 'text'}
            tr '', ->
                td '', ''
                td '', ->
                    button '.js-link-editor-update-btn.button', title: 'Accept changes', 'Submit'
                    button '.js-link-editor-remove-btn.button', title: 'Remove link', 'Remove'

linkPopupTmpl = ->
    div '.js-link-popup.link-popup', tabIndex: '0', ->
        a '.js-link-anchor', ->
            div '.js-link-img', ''
            span '.js-link-text', ''
        button '.js-link-popup-change.button', 'Change'

exports.renderLinkEditor = ck.compile(linkEditorTmpl)

exports.renderLinkPopup = ck.compile(linkPopupTmpl)