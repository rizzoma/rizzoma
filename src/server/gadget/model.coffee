PluginModel = require('../blip/plugin_model').PluginModel
GADGET_NODE = 'GADGET'

class GadgetModel extends PluginModel
    ###
    Класс, представляющий модель Open Social гаджета.
    ###
    constructor: (blip) ->
        ###
        @param _blip: BlipModel
        ###
        super(blip)

    getName: () ->
        ###
        Возвращает имя плагина.
        ###
        return 'gadget'

    getList: () ->
        gadgets = []
        @_blip.iterateBlocks((type, block, position) ->
            params = block.params
            return if type != GADGET_NODE or not params
            gadgets.push({
                position: position
                random: params.RANDOM
            })
        )
        return gadgets

    checkOpPermission: (op, user) ->
        gadget = @_getByPosition(op.p)
        return if not gadget
        params = op.paramsi or op.paramsd
        return if not params
        for key, value of params
            #в объекте всегда будет только одно поле, так что сразу выйдем
            return key[0] == '$'
        return

module.exports.GadgetModel = GadgetModel
