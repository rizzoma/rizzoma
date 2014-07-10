###
Вспомогательные методы для сервера
###
request = require('request')

module.exports.proxy = (proxy_base_url, request_options = {}) ->
    ###
    Миддлеварь для connect и express, которая проксирует запросы на другой сервер
    @param {String} proxy_base_url URL, на который надо проксировать запросы, без завершающего слеша; к нему будет дописан req.url,
    @param {Object} request_options опции, которые будут переданы методу request.
    ###
    return (req, res, next) ->
        throw new Error 'Base URL for proxy required' unless proxy_base_url
        r = request(proxy_base_url + req.url)
        req.pipe(r)
        r.pipe(res)
        