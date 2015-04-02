ck = window.CoffeeKup

publicSearchPanelTmpl = ->
    div '.js-public-search-header.public-search-header', ->
        div '.public-search-query-container', ->
            input '#js-public-search-query.public-search-query', type: 'text'
            div '#js-run-public-search.search-icon', ''
            div '.js-tags-block tags-block', ->
                a {href: '#', 'data-tag': '#Education'}, "#Education"
                a {href: '#', 'data-tag': '#Rizzoma'}, "#Rizzoma"
                a {href: '#', 'data-tag': '#Velocar'}, "#Velocar"
                a {href: '#', 'data-tag': '#Ukraine'}, "#Ukraine"
    div '#js-public-search-results.search-results', ''

publicSearchTopicTmpl = ->
    unreadCount = @item.totalUnreadBlipCount
    unread = ''
    unread = '.unread' if unreadCount
    waveId = h(@item.waveId)
    a ".js-search-result.search-result-item#{h(unread)}", {id: @item.id, href:"#{h(@prefix)}#{waveId}/"}, ->
        div ".js-text-content.text-content", ->
            div '.wave-title', ->
                text h(@item.title)
                snippet = ' ' + @item.snippet
                span '.item-snippet', h(snippet)
        div '.js-wave-info.wave-info', ->
            button '.js-follow.follow.button', h(@item.followButtonText)
            div '.js-info.info', ->
                nameTitle = ''
                if @item.name?
                    nameTitle = @item.name
                avatar = '/s/img/user/unknown.png'
                if @item.avatar? and @item.avatar != ''
                    avatar = @item.avatar
                div '.last-editing.avatar', {style:"background-image: url(#{h(avatar)})", title: h(nameTitle)}, h(@item.initials)
                div '.last-changed', {title: h(@item.fullChangeDate)}, h(@item.changeDate)
                div '.clearer', ''
        div '.clearer', ''
        div '.js-unread-blips-indicator.unread-blips-indicator', ->
            len = @item.unreadLineLen
            div '', {style: "height: #{h(len)}%"}, ''

exports.renderHeader = ck.compile(publicSearchPanelTmpl)

exports.renderResultItem = ck.compile(publicSearchTopicTmpl)