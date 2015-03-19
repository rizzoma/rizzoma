ck = window.CoffeeKup

waveTmpl = ->
    div '.js-scroll-up .js-scroll .drag-scroll-up', ->
        div '.js-scroll-u-1000 .scroll-20', {offset: '-1000'}
        div '.js-scroll-u-500 .scroll-20', {offset: '-500'}
        div '.js-scroll-u-250 .scroll-20', {offset: '-250'}
        div '.js-scroll-u-50 .scroll-20', {offset: '-50'}
    div '.js-wave-panel.wave-panel', ''
    contentClasses = '.js-wave-content.wave-content'
    contentClasses += '.no-editing' if @isAnonymous
    div contentClasses, ->
        if not @empty
            div '.js-wave-blips.wave-blips', ->
                div '.js-container-blip container-blip', ''#->
                if not @isAnonymous
                    div 'topic-url', ->
                        a 'js-topic-url', {href: @url}, 'Open as topic'
            div '.js-topic-mindmap-container.topic-mindmap-container', ''
    div '.js-scroll-down .js-scroll .drag-scroll-down', ->
        div '.js-scroll-d-50 scroll-20', {offset: '50'}
        div '.js-scroll-d-250 scroll-20', {offset: '250'}
        div '.js-scroll-d-500 scroll-10', {offset: '500'}
        div '.js-scroll-d-1000 scroll-10', {offset: '1000'}


blipMenuTmpl = ->
    div "js-playback-menu playback-menu", ->
        button 'js-calendar-button calendar-button delimitered-right', {title: "Current topic state at #{@currentDate}"}, ->
            text @currentDate
        button 'js-fast-back-button fast-back-button icon-button delimitered-right', {title: 'Fast back'}, ->
            div 'icon', ''
        button 'js-back-button back-button icon-button delimitered-right', {title: 'Back'}, ->
            div 'icon', ''
        button 'js-forward-button forward-button icon-button delimitered-right', {title: 'Forward'}, ->
            div 'icon', ''
        button 'js-fast-forward-button fast-forward-button icon-button delimitered-right', {title: 'Fast forward'}, ->
            div 'icon', ''
        button 'js-copy-button copy-button delimitered-right', {title: 'Copy'}, ->
            'Copy'
        button 'js-replace-button replace-button', {title: 'Replace'}, ->
            'Replace'


module.exports =
    renderWave: ck.compile(waveTmpl)
    renderBlipMenu: ck.compile(blipMenuTmpl)
