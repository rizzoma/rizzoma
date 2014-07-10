ck = window.CoffeeKup

errorTmpl = ->
    ###
    Шаблон ошибки на странице
    ###
    if @error and @error.logId
        code = ' with the code: ' + @error.logId
    else
        code = ''
    text h("An unknown error occurred#{code}.")
    br '', ''
    text h("Please ")
    a '.js-refresh-link', 'refresh page'

exports.renderError = ck.compile(errorTmpl)
