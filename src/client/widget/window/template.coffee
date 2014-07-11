ck = window.CoffeeKup

baseWindowTmpl = ->
    div '.widget-window', ->
        if @title
            div '.widget-window-header.js-window-header', ->
                span '', h(@title)
                if @closeButton
                    span '.close-icon.js-window-close-btn', ''
        div '.widget-window-body.js-window-body', ''

centeredWindowBgTmpl = ->
    div '.widget-centered-window-bg', ''

exports.renderBaseWindow = ck.compile(baseWindowTmpl)

exports.renderCenteredWindowBg = ck.compile(centeredWindowBgTmpl)
