ck = window.CoffeeKup

noResultsTmpl = ->
    div '.js-no-results.no-results', 'No results'

errorTmpl = ->
    div '.js-search-error.search-error', 'Error occurred'

statusBarTmpl = ->
    div '.js-status-bar.status-bar', ->
        div '.js-status-bar-text', ''

exports.renderEmptyResult = ck.compile(noResultsTmpl)

exports.renderError = ck.compile(errorTmpl)

exports.renderStatusBar = ck.compile(statusBarTmpl)