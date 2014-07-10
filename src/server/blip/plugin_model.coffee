Model = require('../common/model').Model
NotImplementedError = require('../../share/exceptions').NotImplementedError

class PluginModel extends Model
    ###
    Базовый класс плагина.
    ###
    constructor: (@_blip) ->
        super('plugin')

    getName: () ->
        ###
        Возвращает имя плагина.
        ###
        throw new NotImplementedError()

    _getPluginData: () ->
        ###
        Возвращает сохраненые данные планина.
        @returns: object
        ###
        return @_blip.pluginData[@getName()]

    _getPluginPath: () ->
        ###
        Возвращает путь, по которому находятся данные плагина.
        @returns array
        ###
        return ['pluginData', @getName()]

    @getSearchIndexHeader: () ->
        ###
        Возвращает индексируемые поля для заголовка индекса.
        Должен быть переопределен во всех плогинах, данные которых подлежат индексации.
        @returns: array
        ###
        return []

    getSearchIndex: () ->
        ###
        Возвращает индексируемые поля для индекса.
        Должен быть переопределен во всех плогинах, данные которых подлежат индексации.
        @returns: array
        ###
        return []

    getTextParams: () ->
        ###
        Вспомогательный метод для @_blip.getText()
        Если плагин должен добавлять свой текст к тексту блипа должен быть переопределен в классе плагина
        @returns: object
            type: string - ключ, тип блока в блипе
                attr: название атрибута содержащего текст в блоке
                decorator: function(string): string декоратор текста
        ###
        return {}

    checkOpPermission: () ->
        return false

    getChangingState: (ops) ->
        ###
        @param ops: arrya
        @returns: int
        Вернет число, двоичное представление это битовая сумма констант. По костанте на операцию со сдвигов на 2 разряда вправо.
        ###
        return 0

    getList: () ->
        ###
        Возвращает список плагинов данного типа в моделе. Переопределяется в наследниках.
        @returns: array
        ###
        return []

    _getByPosition: (position) ->
        ###
        Возвращает экземпляр гаджета по позиции в блипе.
        @param position: int
        @returns: PluginModel
        ###
        for plugin in @getList()
            return plugin if plugin.position == position
        return

module.exports.PluginModel = PluginModel
