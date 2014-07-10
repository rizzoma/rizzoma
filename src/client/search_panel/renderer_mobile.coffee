ck = window.CoffeeKup
DomUtils = require('../utils/dom')

emptyResultsTmpl = ck.render ->
    div 'js-no-results search-item raw-text', 'No results'

errorTmpl = ck.render ->
    div 'js-search-error search-item raw-text', 'Error occurred'

loadingTmpl = ck.render ->
    div 'search-item raw-text', 'Loading'

renderSearchList = ck.compile ->
    items = @itemList
    for item in items
        bold = if item.isBolded then 'bold' else ''
        a "search-item #{bold}", {id: item.id, href: h(item.url)}, ->
            div 'search-item-text', ->
                span 'search-item-title', h(item.title)
                br()
                span 'search-item-snippet', h(item.snippet)
            div 'search-item-user-info', ->
                div 'avatar search-item-avatar', {style: "background-image: url('#{h(item.avatar)}')", \
                               title: "#{h(item.name || '')}"}
                div 'search-item-date', {title: "#{h(item.dateTitle)}"}, h(item.date)


renderTaskList = ck.compile ->
    renderTasks = (items) ->
        for item in items
            bold = if item.isBolded then 'bold' else ''
            a "search-item #{bold}", {id: item.id, href: h(item.url)}, ->
                div 'search-item-text', ->
                    span 'search-item-title', h(item.title)
                    br()
                    span 'search-item-snippet', h(item.snippet)
                div 'search-item-user-info', ->
                    div 'avatar search-item-avatar', {style: "background-image: url('#{h(item.avatar)}')", \
                                   title: "#{h(item.name || '')}"}
                    div 'search-item-date', {title: "#{h(item.dateTitle)}"}, h(item.date)

    renderTasks(@items)
    return if not @completedItems or not @completedItems.length
#    div '.completed-tasks', ->
    detailParams = {}
    if @opened
        detailParams.open = yes
    details 'js-completed-tasks-block completed-tasks-block', detailParams, ->
        summary 'search-item completed-tasks-summary', "Completed tasks — #{@completedItems.length}"
        div '.completed-task-list', ->
            renderTasks(@completedItems)


renderTopicList= ck.compile ->
    topics = @itemList
    for topic in topics
        bold = if topic.isBolded then 'bold' else ''
        a "search-item #{bold}", {id: topic.id, href: h(topic.url)}, ->
            div 'unread-blips-indicator', ->
                div 'js-unread-blips-indicator', {style: "height: #{h(topic.unreadLength)}%;"}
            div 'search-item-text', ->
                span 'search-item-title', h(topic.title)
                br()
                span 'search-item-snippet', h(topic.snippet)
            div 'search-item-user-info', ->
                div 'avatar search-item-avatar', {style: "background-image: url('#{h(topic.avatar)}')", \
                               title: "#{h(topic.name || '')}"}
                div 'search-item-date', {title: "#{h(topic.dateTitle)}"}, h(topic.date)

class Renderer
    renderError: (container) ->
        result = DomUtils.parseFromString(errorTmpl)
        @__fillContainer(container, result)

    renderEmptyResult: (container) ->
        result = DomUtils.parseFromString(emptyResultsTmpl)
        @__fillContainer(container, result)

    renderLoading: (container) ->
        result = DomUtils.parseFromString(loadingTmpl)
        @__fillContainer(container, result)

    renderItems: (container, itemList) ->
        params = {itemList}
        result = DomUtils.parseFromString(renderSearchList(params))
        @__fillContainer(container, result)

    __fillContainer: (container, content) ->
        DomUtils.empty(container).appendChild(content)


class TopicsRenderer extends Renderer
    renderItems: (container, itemList) ->
        params = {itemList}
        result = DomUtils.parseFromString(renderTopicList(params))
        @__fillContainer(container, result)


class TasksRenderer extends Renderer
    renderItems: (container, items, completedItems) ->
        params = {items, completedItems}
        params.opened = container.getElementsByClassName('js-completed-tasks-block')[0]?.hasAttribute('open')
        result = DomUtils.parseFromString(renderTaskList(params))
        @__fillContainer(container, result)


module.exports =
    Renderer: Renderer
    TopicsRenderer: TopicsRenderer
    TasksRenderer: TasksRenderer
