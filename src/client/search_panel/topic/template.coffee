ck = window.CoffeeKup

searchPanelTmpl = ->
    div '.js-search-header.search-header', ->
        div '.search-query-container', ->
            input '#js-search-query.search-query', type: 'text'
            div 'js-clear-search-query clear-search-query-button hidden', ''
            div 'js-show-search-menu show-search-menu-button', ''
            div '#js-run-search.search-icon', ''
            span 'js-topic-filter-label topic-filter-label', ''
        div 'js-search-menu search-menu hidden', ->
            div 'tags-block', ->
                div 'js-tags-block', ->
                    span 'You have no #tags'
            hr ''
            div 'js-topic-filter topic-filter', ->
                first = yes
                for tt in @topicTypes
                    cl = if first then 'active' else ''
                    a cl, {href: '#', 'data-value': tt.value, 'data-text': tt.text}, tt.text
                    first = no
    div '#js-search-results.search-results', ''

topicTmpl = ->
    unreadCount = @item.totalUnreadBlipCount
    unread = ''
    unread = '.unread' if unreadCount
    waveId = h(@item.waveId)
    a ".js-search-result.search-result-item#{h(unread)}", {id: @item.id, href:"#{h(@prefix)}#{waveId}/"}, ->
        div '.js-unread-blips-indicator.unread-blips-indicator', ->
            len = @item.unreadLineLen
            div '', {style: "height: #{h(len)}%"}, ''
        div ".js-text-content.text-content", ->
            div '.wave-title', ->
                span h(@item.title)
                snippet = ' ' + @item.snippet
                br '', ''
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

tagListTmpl = ->
    for tag in @tags
        hTag = "##{h(tag)}"
        a {href: '#', 'data-tag': hTag}, "#{hTag} "

exports.renderHeader = ck.compile(searchPanelTmpl)

exports.renderResultItem = ck.compile(topicTmpl)

exports.renderTagList = ck.compile(tagListTmpl)
