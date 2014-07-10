url = require('url')

module.exports.parseGACookie = parseGACookie = (cookie) ->
    ###
    Парсит Google Analytics cookie вида:
    148911669.1334139348.1.1.utmcsr=habrahabr.ru|utmccn=(referral)|utmcmd=referral|utmcct=/post/141312/
    148911669.1325085400.1.1.utmcsr=148911669.1325085400.1.1.utmcsr=habrahabr.ru|utmccn=(referral)|utmcmd=referral|utmcct=
    Возвращает полученный referer url.
    ###
    utmcsrRe = /utmcsr=([a-z0-9-.]+)\|/
    utmcctRe = /utmcct=([^|]+)/
    host = ''
    pathname = ''
    res = utmcsrRe.exec(cookie)
    host = res[1] if res and res[1]
    res = utmcctRe.exec(cookie)
    pathname = res[1] if res and res[1]
    return host + pathname

isExternalReferer = (referer) ->
    ###
    Проверяет наличие реферера и то, что он со стороннего сайта
    @return {Bool} true|false
    ###
    return false if not referer

    try
        urlParsed = url.parse(referer)
    catch e
        return false

    if urlParsed.host and urlParsed.host.search('rizzoma.com') == -1 and urlParsed.host.search('localhost') == -1
        return true
    return false

userInfoMiddleware = (req, res, next) ->
    ###
    Для незалогиненных пользователей сохраняет в сессию url, с которого они пришли (из HTTP-заголовка Referer, из куки Гугл Аналитики или из куки "cr")
    ###
    if not req.loggedIn
        # Получаем из заголовка Referer
        if not req.session.referer and isExternalReferer(req.headers.referer)
            req.session.referer = req.headers.referer

        # Получаем из cookie Google Analytics
        if not req.session.referer and req.cookies.__utmz
            referer = parseGACookie(req.cookies.__utmz)
            req.session.referer = referer if referer

        # Получаем из cookie "cr" ("creation referer"), которую устанавливает Nginx для страниц, которые он раздает
        if not req.session.referer and isExternalReferer(req.cookies.cr)
            req.session.referer = req.cookies.cr

    # удаляем cookie
    if req.cookies.cr
        res.clearCookie('cr', {path: '/'})

    # достаем landing и channel откуда пришел пользователь
    cl = req.cookies.cl
    if cl
        channel = 'bylink'
        landing = 'unknown'
        urlParams = cl.split('?')
        if urlParams.length > 1
            channel = 'ads' if urlParams[1].search(/utm_medium=cpc(&|$)/) != -1
            channel = 'ads' if urlParams[1].search(/gclid=/) != -1
            channel = 'ads' if urlParams[1].search(/utm_medium=ad(&|$)/) != -1 and urlParams[1].search(/utm_source=fb(&|$)/) != -1
            channel = 'addgmail' if urlParams[1].search(/utm_campaign=adduser(new|existing)(&|$)/) != -1
            channel = 'addfbchat' if urlParams[1].search(/from=fbchat_addusernew(&|$)/) != -1
            channel = urlParams[1].match(/chromeapp\w*/)[0] if urlParams[1].search(/chromeapp\w*/) != -1
        landing = urlParams[0]
        landing = '/topic/id/' if (landing and /\/topic\/[0-9a-zA-Z]{32}/.test(landing))
        req.session['channel'] = channel
        req.session['landing'] = landing
        req.session['cl'] = cl
        res.clearCookie('cl', {path: '/'})

    next()
    
module.exports.userInfoMiddleware = userInfoMiddleware
