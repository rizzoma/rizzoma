ck = window.CoffeeKup

panelHeaderTmpl = ->
    div '.js-task-list-header.task-list-header', ->
        div '.task-list-query-container', ->
            input '#js-task-list-query.task-list-query', type: 'text'
            div '#js-run-task-list.search-icon', ''
            select '.js-task-filter.task-filter', ->
                for tt, index in @taskTypes
                    # Если value == false, то jquery отдает вместо него текст
                    option {value: index + 1}, tt.text
    div '.js-task-time-filters.task-time-filters', ->
        select '.js-close-date.task-time-filter', ->
            option '.js-all-tasks', {value: '.js-all-tasks', selected: true}, 'All tasks'
            option '.js-yesterday-tasks', {value: '.js-yesterday-tasks'}, 'Yesterday'
            option '.js-today-tasks', {value: '.js-today-tasks'}, 'Today'
            option '.js-tomorrow-tasks', {value: '.js-tomorrow-tasks'}, 'Tomorrow'
        button '.js-no-date-tasks.task-time-filter', ->
            text 'No date'
            span '.js-task-filter-quantity.task-filter-quantity', ''
        div '.tasks-with-date-filter-container', ->
            input '.js-tasks-with-date-filter-input.tasks-with-date-filter-input', {type: 'text'}
            button '.js-with-date-tasks.tasks-with-date-filter.task-time-filter', ->
                span '.js-tasks-with-date-filter-label.tasks-with-date-filter-label', 'With date'
                span '.js-task-filter-quantity.task-filter-quantity', ''
    div '.js-task-list-results.task-list-results.completed-hidden', ''

panelTmpl = ->
    prefix = @prefix
    renderTasks = (tasks) ->
        for task in tasks
            unread = if not task.isRead then '.unread' else ''
            taskLink = "#{h(prefix)}#{h(task.waveId)}/#{h(task.blipId)}/"
            a ".js-task-list-result.search-result-item#{unread}", {id: task.id, href:taskLink}, ->
                div ".text-content", ->
                    div '.task-title', ->
                        if task.strDeadlineTime? or task.strDeadlineDate?
                            span ".task-time-info#{if task.overdue then '.overdue' else ''}#{if task.today then '.today' else ''}", "#{if task.strDeadlineDate? then h(task.strDeadlineDate) else ''} #{if task.strDeadlineTime? then h(task.strDeadlineTime) else ''} "
                        text h(task.title + " ")
                        span '.item-snippet', h(task.snippet)
                div ".task-info", ->
                    avatar = task.senderAvatar
                    name = task.senderName
                    div '.last-editing.avatar', {style:"background-image: url(#{h(avatar)})", title: h(name)}, h(task.initials)
                div '.clearer', ''
    renderTasks(@incompleteTasks)
    return if not @completedTasks.length
    div '.completed-tasks', ->
        div '.js-completed-tasks-header.completed-tasks-header', ->
            div '.completed-tasks-arrow', ''
            text "Completed tasks — #{@completedTasks.length}"
        div '.completed-task-list', ->
            renderTasks(@completedTasks)

exports.renderHeader = ck.compile(panelHeaderTmpl)

exports.renderResults = ck.compile(panelTmpl)