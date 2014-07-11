Model = require('../common/model').Model
DateUtils = require('../utils/date_utils').DateUtils
IdUtils = require('../utils/id_utils').IdUtils

TIP_LIST_ID = require('./constants').TIP_LIST_ID

TIP_ID_LENGTH = 10

class TipListModel extends Model
    ###
    Модель списка подсказок.
    ###
    constructor: (@tips=[], @lastModified=null) ->
        @id = TIP_LIST_ID
        super('tips_list')

    addTip: (text) ->
        ###
        Добавляет подсказку.
        @param tipText: HTML string
        ###
        now = DateUtils.getCurrentTimestamp()
        newTip = {id: IdUtils.getRandomId(TIP_ID_LENGTH), text: text, creationDate: now}
        @tips.push(newTip)
        @lastModified = now

    removeTip: (id) ->
        ###
        Удаляет подсказку.
        @param id: string
        ###
        [tip, index] = @_getTip(id)
        return if not tip
        @tips[index..index] = []

    editTip: (id, text) ->
        ###
        Редактирует подсказку.
        @param id: string
        @param tipText: HTML string
        ###
        [tip, index] = @_getTip(id)
        return if not tip
        tip.text = text

    _getTip: (id) ->
        ###
        Возвращает подсказку и ее индекс в списке.
        @param id: string
        @returns [tip, int]
        ###
        for tip, index in @tips
            return [tip, index] if tip.id == id
        return [null, -1]

    toClientObject: () ->
        return {
            tips: @tips
            lastModified: @lastModified
        }

module.exports.TipListModel = TipListModel
