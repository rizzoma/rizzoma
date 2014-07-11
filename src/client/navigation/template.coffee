ck = window.CoffeeKup

navigationPanelTmpl = ->
    ###
    Шаблон навигационной панели
    ###
    div '.js-resizer.resizer', {title: "Resize panels"}, ->
        div '', ''
    div '.js-lists-container.search-lists-container', ->
        div '.js-search-container.search', ''
        return if not @loggedIn
        div '.js-message-list-container.message-list-container.search', ''
        div '.js-task-list-container.task-list-container.search', ''
        div '.js-public-search-container.public-search-container.search', ''
        div '.js-market-panel-container.market-panel-container.search', ''

tipsBoxTmpl = ->
    ###
    Шаблон блока с подсказками
    ###
    div ".js-tips-box.tips-box", ->
        div '.tips-toggle-container', ->
            div '.js-tips-toggle', ->
                div '.diag-border', ''
                span '.tips-toggle-text-max', 'Minimize shortcuts'
                span '.tips-toggle-text-min', 'Maximize shortcuts'
                div '.tips-toggle-status', ''
            div '.clearer', ''
        div '.tips-delimiter', ''
        div '.clearer', ''
        table '.tips-head-container', {cellspacing: 0, cellpadding: 0}, ->
            tr ->
                td ->
                    a '', {href: "/?no_auth_redirect", title: "Rizzoma"}, ->
                        img '.rizzoma-logo', {src: "/s/img/tips-rizzoma-logo.png"}
                td '.actions', ->
                    if @isDesktopChrome
                        a '', {href: "https://chrome.google.com/webstore/detail/rizzoma-research-sidebar/mfhnlfcipodclfgnfekflgapmnmkgnmc", title: "Install our Chrome Side Bar", target: "_blank"}, ->
                            div '.chrome-webstore-ico', ''
                            text 'Side Bar'
                    else
                        a '', {href: "http://blog.rizzoma.com/", title: "Go to our blog", target: "_blank"}, 'Blog'
                        a '', {href: "http://blog.rizzoma.com/category/methodology/", title: "Go to user cases", target: "_blank"}, 'User cases'
                    text '<script src="//platform.linkedin.com/in.js" type="text/javascript"></script><script type="IN/FollowCompany" data-id="2619456" data-counter="right"></script>'
        div '.tips-content', ->
            if window.firstVisit
                div '.js-tips-video.tips-video', ->
                    div '.js-play-pict.play-pict', ''
                    div '.video-name', ->
                        div 'Watch the video First Steps in Rizzoma'
            else
                div '.js-folded-tips-video.folded-tips-video', ->
                    span '.folded-video-name', 'First steps in Rizzoma:'
                    button '.js-play-pict.folded-play-pict.button', 'Play video'
            div ->
                div ->
                    img '', {src: "/s/img/tips-reply-ico.png"}
                    text 'Ctrl+Enter'
                div ->
                    img '', {src: "/s/img/tips-hide-ico.png"}
                    text 'Ctrl+Shift+&uarr;'
                div ->
                    img '', {src: "/s/img/tips-@.png"}
                    text 'Mention'
            div ->
                div ->
                    img '', {src: "/s/img/tips-next-unread-ico.png"}
                    text 'Ctrl+Space'
                div ->
                    img '', {src: "/s/img/tips-show-ico.png"}
                    text 'Ctrl+Shift+&darr;'
                div ->
                    img '', {src: "/s/img/tips-tilda.png"}
                    text 'Task'

exports.renderNavigationPanel = ck.compile(navigationPanelTmpl)

exports.renderTipsBox = ck.compile(tipsBoxTmpl)