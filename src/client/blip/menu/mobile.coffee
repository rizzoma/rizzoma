blipCommonMenuTmpl = ->
    div 'js-blip-menu blip-menu', ->
        if @hasServerId then disabled = '' else disabled = true
        div 'menu-item', ->
            button 'js-hide-all-inlines hide-all-inlines blip-menu-item', {title: 'Hide replies (Ctrl+Shift+Up)'}, ->
                div ''
        div 'menu-item', ->
            div 'blip-menu-delimiter', ''
            button 'js-show-all-inlines show-all-inlines blip-menu-item', {title: 'Show replies (Ctrl+Shift+Down)'}, ->
                div ''
#        div 'menu-item', ->
#            div 'blip-menu-delimiter', ''
#            active = ''
#            active = '.active' if @isFoldedByDefault
#            button "js-is-folded-by-default is-folded-by-default blip-menu-item#{active}", {title: 'Hidden by default', disabled: disabled}, ->
#                span ->
#                    div '', ''
#                    text 'Hidden'
        div 'menu-item copy-paste-blip-item copy', ->
            div 'blip-menu-delimiter', ''
            button 'js-copy-blip-button blip-menu-item', {title: 'Copy reply', disabled: disabled}, 'Copy'
        div 'menu-item copy-paste-blip-item paste-at-cursor', ->
            div 'blip-menu-delimiter', ''
            button 'js-paste-at-cursor-button blip-menu-item', {title: 'Paste at cursor', disabled: disabled}, 'at cursor'
        div 'menu-item copy-paste-blip-item paste-as-reply', ->
            div 'blip-menu-delimiter', ''
            button 'js-paste-after-blip-button blip-menu-item', {title: 'Paste as reply', disabled: disabled}, 'as reply'
        div 'blip-menu-delimiter', ''
        button 'js-delete-blip blip-menu-item delete-blip', {title: 'Delete'},  ->
            div '', ''

renderBlipCommonMenu = window.CoffeeKup.compile(blipCommonMenuTmpl)

class BlipMenu
    constructor: (params) ->
        @_container = document.createElement('span')
        @_render(params)

    _render: (params) ->
        ###
        Рендерим блоки меню
        ###
        $(@_container).append(renderBlipCommonMenu(params))

    getContainer: ->
        return @_container

    enableAllButtons: ->
        $(@_container).find('button').prop('disabled', false)

exports.BlipMenu = BlipMenu
