ck = window.CoffeeKup

recipientTmpl = ->
    # split is added to prevent autocorrect
    span 'blip-recipient-container', ->
        span 'editor-el-split', '|'
        span 'blip-recipient', ->
            span 'blip-recipient-text', "@#{h(@name)}"
        span 'editor-el-split', '|'

recipientInputTmpl = ->
    span '.recipient-input-container', ->
        input '.js-recipient-input .recipient-input', {type: "text", tabindex: "0"}
        span {style: "position: absolute; left: 3px;"}, '@'

recipientPopupTmpl = ->
    div '.mention-recipient-popup', ->
        div '.recipient-info', ->
            div '.avatar', {style:"background-image: url(#{h(@avatar)})"}, h(@initials)
            div '.wave-participant-name-email', ->
                div '.wave-participant-name', h(@name)
                div '.wave-participant-email', h(@email)
        div '.mention-bottom-container', ->
            params = {}
            params.disabled = 'disabled' if not @canDelete
            button '.js-remove-recipient.remove-recipient', params, 'Delete'
            if @showConvertButton
                params = {}
                params.disabled = 'disabled' if not @canConvert
                button '.js-convert-to-task.convert-to-task-button', params, 'Convert to'

exports.renderRecipient = ck.compile(recipientTmpl)

exports.renderRecipientInput = ck.compile(recipientInputTmpl)

exports.renderRecipientPopup = ck.compile(recipientPopupTmpl)
