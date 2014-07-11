###
Вспомогательные методы для сервера
###
express = require('express')

module.exports.serveStatic = (root, path=null, options={}) ->
    ###
    Раздает статические файлы из указанной директории.
    Отличается от миддлевари express.static/connect.static возможностью
    использовать этот метод в роутерах с раздачей статики по разным url
    (с отрезанием начальной части адреса).
    Путь к отдаваемому файлу вычисляется как:
    filename = root + (options.path || req.params[0] || req.url),
    где req.params[0] - часть url, из регулярки в описании роута,
    req.url - полный url, используется, если роут не описан регулярным выражением со скобками.

    @param {String} root относительно этой папки ищем файлы,
    @param {String} path путь к файлу относительно папки root (если не указан,
        то используем первый параметр из регулярки описания роута, либо url запроса)
    @param {Object} options:
     - `maxAge` Browser cache maxAge in milliseconds. defaults to 0
     - `hidden` Allow transfer of hidden files. defaults to false
    ###
    return (req, res, next) ->
        options = options || {};
        # root required
        throw new Error 'static() root path required' unless root
        options.root = root
        options.getOnly = true
        options.path = req.params[0] || req.url
        express.static.send req, res, next, options
