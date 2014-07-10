ck = window.CoffeeKup

blipTmpl = ->
    if not @isRoot
        div '.js-blip-menu-container.blip-menu-container', ''
        div '.js-blip-info-container.blip-info', ->
            span '.js-shown-contributor', ''
            div ->
                div '.edit-date', {title: h(@fullDatetime)}, h(@datetime)
    div '.js-editor-container.editor-container', ->
        if not @isRoot
            div '.js-blip-unread-indicator.unread-indicator', style: 'display: none;', ->
    if not @isAnonymous
        div '.js-bottom-blip-menu.bottom-blip-menu', ->
            button 'js-finish-edit finish-edit-button', {
                title: 'Done (Ctrl+E, Shift+Enter)',
                onMouseDown: "_gaq.push(['_trackEvent', 'Blip usage', 'To read mode', 'bottom button']);"
            }, 'Done'
            button '.js-blip-reply-button.blip-reply-button', {title: 'Write a reply to this thread'}, ->
                div '.text', 'Write a reply...'
                div '.avatar', {style: "background-image: url(#{h(window.userInfo.avatar)})"}, ''
                div '.gradient', ''

exports.renderBlip = ck.compile(blipTmpl)
