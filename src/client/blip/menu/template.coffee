ck = window.CoffeeKup

blipMenuTmpl = ->
    div "js-read-only-block read-only-menu", ->
        button "js-change-mode change-mode delimitered-right", {
            title: 'To edit mode (Ctrl+E)'
            onClick: "_gaq.push(['_trackEvent', 'Blip usage', 'To edit mode', 'top button']);"
        }, 'Edit'
        div 'js-fold-unfold-block fold-unfold-block', ->
            button "js-hide-all-inlines hide-all-inlines icon-button", {title: 'Hide comments (Ctrl+Shift+Up)'}, ->
                div '.icon', ''
            button 'js-show-all-inlines show-all-inlines delimitered-right icon-button', {
                title: 'Show comments (Ctrl+Shift+Down)'
            }, ->
                div '.icon', ''
        button 'js-copy-blip-link get-blip-link delimitered-right icon-button', {title: 'Get direct link'}, ->
            div '.icon', ''
        button "js-is-folded-by-default is-folded-by-default delimitered-right icon-button", {
            title: 'Collapse this thread by default'
        }, 'Hide'
        button 'js-delete-blip delete-blip delimitered-right icon-button', {title: 'Delete comment'}, ->
            div 'icon', ''
        div 'gearwheel-container', ->
            button 'js-gearwheel gearwheel icon-button', {title: 'Other'}, ->
                div 'icon', ''
            div 'js-other-blipmenu-container other-blipmenu-container other-blip-menu', -> # TODO: remove other-blipmenu-container
                div 'triangle', ->
                    div ->
                        div '',''
                div 'list-menu-button', ->  #оборачиваем все кнопки в див, чтобы они заняли все меню по ширине
                    button 'js-copy-blip-button copy-blip-button', {title: 'Copy comment'}, 'Copy comment'
                div '.list-menu-button', ->
                    button 'js-paste-after-blip-button paste-as-reply', {title: 'Paste as reply'}, 'Paste as reply'
                div 'list-menu-button', ->
                    button 'js-paste-at-cursor-button paste-at-cursor', {title: 'Paste at cursor'}, 'Paste at cursor'
                div 'list-menu-button', ->
                    button 'js-copy-blip-link', {title: 'Copy link'}, 'Copy link'

    div 'js-edit-block edit-menu', ->
        button 'js-change-mode change-mode delimitered-right', {
            title: 'Done, switch to read mode (Ctrl+E, Shift+Enter)'
            onMouseDown: "_gaq.push(['_trackEvent', 'Blip usage', 'To read mode', 'top button']);"
        }, 'Done'
        button "js-undo undo icon-button", title: 'Undo (Ctrl+Z)', ->
            div '.icon', ''
        button 'js-redo redo delimitered-right icon-button', title: 'Redo (Ctrl+Shift+Z, Ctrl+Y)', ->
            div '.icon', ''
        button 'js-manage-link add-url icon-button', {title: 'Insert link (Ctrl+L)'}, ->
            div '.icon', ''
        button 'js-insert-file insert-file icon-button', {title: 'Insert attachment'}, ->
            div '.icon', ''
        button 'js-insert-image insert-image delimitered-right icon-button', {title: 'Insert image'}, ->
            div '.icon', ''
        button 'js-make-bold make-bold icon-button', {title: 'Bold (Ctrl+B)'}, ->
            div '.icon', ''
        button 'js-make-italic italic icon-button', {title: 'Italic (Ctrl+I)'}, ->
            div '.icon', ''
        button 'js-make-underlined make-underlined icon-button', {title: 'Underline (Ctrl+U)'}, ->
            div '.icon', ''
        button 'js-make-struckthrough make-struckthrough icon-button', {title: 'Strikethrough'}, ->
            div '.icon', ''
        span {style: 'position: relative;'}, ->
            button 'js-make-background-color make-background-color icon-button', {title: 'Text background color'}, ->
                div 'js-icon icon', ''
            div 'js-color-panel color-panel', ->
                button 'color-choice', '' for i in [1..7]
        button 'js-clear-formatting clear-formatting icon-button', {title: 'Clear formatting'}, ->
            div 'icon', ''
        button 'js-make-bulleted-list bulleted icon-button', {title: 'Bulleted list'}, ->
            div 'icon', ''
        button 'js-make-numbered-list numbered delimitered-right icon-button', {title: 'Numbered list'}, ->
            div 'icon', ''
        button "js-is-folded-by-default is-folded-by-default delimitered-right icon-button", {
            title: 'Collapse this thread by default'
        }, 'Hide'
        button 'js-delete-blip delete-blip delimitered-right icon-button', {title: 'Delete comment'}, ->
            div '.icon', ''
        div 'gearwheel-container', ->
            button 'js-gearwheel gearwheel icon-button', {title: 'Other'}, ->
                div 'icon', ''
            div 'js-other-blipmenu-container other-blipmenu-container other-blip-menu', -> # TODO: remove other-blipmenu-container
                div 'triangle', ->
                    div ->
                        div '',''
                div 'list-menu-button', ->
                    button 'js-copy-blip-button copy-blip-button', {title: 'Copy comment'}, 'Copy comment'
                div 'list-menu-button', ->
                    button 'js-paste-after-blip-button paste-as-reply', {title: 'Paste as reply'}, 'Paste as reply'
                div 'list-menu-button', ->
                    button 'js-paste-at-cursor-button paste-at-cursor', {title: 'Paste at cursor'}, 'Paste at cursor'
                div 'list-menu-button', ->
                    button 'js-send-button send-message', {title: 'Send'}, 'Send'
                # buttons that doesn't fit to menu
                div 'list-menu-button', ->
                    button 'js-undo undo hidden', 'Undo'
                div 'list-menu-button', ->
                    button 'js-redo redo hidden', 'Redo'
                div 'list-menu-button', ->
                    button 'js-manage-link add-url hidden', 'Manage link'
                div 'list-menu-button', ->
                    button 'js-insert-file insert-file hidden', 'Insert file'
                div 'list-menu-button', ->
                    button 'js-insert-image insert-image hidden', 'Insert image'
                div 'list-menu-button', ->
                    button 'js-make-bold make-bold hidden', 'Make bold'
                div 'list-menu-button', ->
                    button 'js-make-italic italic hidden', 'Make italic'
                div 'list-menu-button', ->
                    button 'js-make-underlined make-underlined hidden', 'Make underlined'
                div 'list-menu-button', ->
                    button 'js-make-struckthrough make-struckthrough hidden', 'Make struckthrough'
                div 'list-menu-button', ->
                    button 'js-make-bulleted-list bulleted hidden', 'Make bulleted list'
                div 'list-menu-button', ->
                    button 'js-make-numbered-list numbered hidden', 'Make numbered list'
                div 'list-menu-button', ->
                    button 'js-clear-formatting clear-formatting hidden', 'Clear formatting'
                div 'list-menu-button', ->
                    button 'js-is-folded-by-default is-folded-by-default hidden', 'Hidden'
                div 'list-menu-button', ->
                    button 'js-delete-blip delete-blip hidden', 'Delete comment'
                div 'list-menu-button', ->
                    button 'js-copy-blip-link', {title: 'Copy link'}, 'Copy link'

copyBlipLinkPopup = ->
    div 'js-copy-blip-link.copy-blip-link', ->
        input '.js-blip-link', {value: h(@url), readonly: "readonly"}

exports.renderCopyBlipLinkPopup = ck.compile(copyBlipLinkPopup)
exports.renderBlipMenu = ck.compile(blipMenuTmpl)
