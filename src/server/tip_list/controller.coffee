async = require('async')
sanitizer = require('sanitizer')
TipListCouchProcessor = require('./couch_processor').TipListCouchProcessor

class TipListController
    ###
    Контроллер списка подсказок.
    ###
    constructor: () ->

    getTipList: (callback) =>
        ###
        Загружает список.
        @param callback: function
        ###
        TipListCouchProcessor.getTipList(callback)

    addTip: (tipText, callback) ->
        ###
        Добавляет подсказку.
        @param tipText: HTML string
        @param callback: function
        ###
        action = (tipList, tipText) =>
            tipList.addTip(@fixTipText(tipText))
        @_modifyTipList(action, tipText, callback)

    removeTip: (id, callback) ->
        ###
        Удаляет подсказку.
        @param id: string
        @param callback: function
        ###
        action = (tipList, id) ->
            tipList.removeTip(id)
        @_modifyTipList(action, id, callback)

    editTip: (id, tipText, callback) ->
        ###
        Редактирует текст подсказки.
        @param id: string
        @param tipText: HTML string
        @param callback: function
        ###
        action = (tipList, id, tipText) =>
            tipList.editTip(id, @fixTipText(tipText))
        @_modifyTipList(action, id, tipText, callback)

    fixTipText: (tipText) ->
        ###
        Чинит введенный HTML.
        @param tipText: HTML string
        @returns: HTML string
        ###
        return sanitizer.sanitize(tipText, (uri) -> uri) #второй параметр - правило преобразования uri.

    _modifyTipList: (action, args..., callback) ->
        ###
        Модифицирует список подсказок.
        @param action: function(tipList, args...) - функция-модификатор
        @param args - произвольные аргументы
        @param callback: function
        ###
        tasks = [
            async.apply(@getTipList)
            (tipList, callback) ->
                action(tipList, args...)
                TipListCouchProcessor.save(tipList, callback)
        ]
        async.waterfall(tasks, callback)

module.exports.TipListController = new TipListController()
