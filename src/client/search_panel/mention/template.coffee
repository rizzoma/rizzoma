ck = window.CoffeeKup

messagePanelHeaderTmpl = ->
    ###
    Отрисовывает хидер панели поиска сообщений
    ###
    div '.js-message-list-header.message-list-header', ->
        div '.message-list-query-container', ->
            input '#js-message-list-query.message-list-query', type: 'text'
            div '#js-run-message-list.search-icon', ''
    div '.js-message-list-results.message-list-results', ''

messageTmpl = ->
    ###
    Отрисовывает панель поиска сообщений
    ###
    unread = ''
    if not @item.isRead
        unread = '.unread'
    messageLink = "#{h(@prefix)}#{h(@item.waveId)}/#{h(@item.blipId)}/"
    a ".js-message-list-result.search-result-item#{h(unread)}", {id: @item.id, href:messageLink}, ->
        div ".text-content", ->
            div '.message-title', ->
                text(h(@item.title + " "))
                span '.item-snippet', h(@item.snippet)
        div '.message-info', ->
            avatar = @item.senderAvatar
            name = @item.senderName
            div '.last-editing.avatar', {style:"background-image: url(#{h(avatar)})", title: h(name)}, h(@item.initials)
            div '.last-changed', {title: h(@item.strFullLastSent)}, h(@item.strLastSent)
            div '.clearer', ''
        div '.clearer', ''

exports.renderHeader = ck.compile(messagePanelHeaderTmpl)

exports.renderResultItem = ck.compile(messageTmpl)