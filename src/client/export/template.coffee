ck = window.CoffeeKup

commonFormTmpl = ->
    div '.js-export-popup.export-popup', ->
        div '.ep-title', 'Export topics'
        div '.ep-select-all-container', ->
            input '.ep-select-all', {type: 'checkbox'}
            'select all'
        ul '.ep-topics', ->
            for topic in @topics
                li '.ep-topic', {'data-id': topic.waveId}, ->
                    input {type: 'checkbox'}
                    topic.title or span '.ep-topic-no-title', '(no title)'
        div '', 'Tip: use the search to narrow down this list.'
        div '.ep-start-container', ->
            button '.ep-start.button', 'Export selected topics'
        div '.ep-archives-container', ->
            span '', 'Recently exported topics:'

archiveListTmpl = ->
    ul '.ep-archives', ->
        if @hasTask
            li '.ep-archive', 'Preparing archive...'
        for archive in @archives
            li '.ep-archive', ->
                a '.ep-archive-link', {href: "//#{window.HOST}/export/#{archive.url}", target: '_blank'},
                    "#{archive.topics} #{if archive.topics is 1 then 'topic' else 'topics'} on #{archive.created}"

exports.renderCommonForm = ck.compile(commonFormTmpl)
exports.renderArchiveList = ck.compile(archiveListTmpl)
