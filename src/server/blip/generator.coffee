IdUtils = require('../utils/id_utils').IdUtils
Generator = require('../common/generator').Generator

class BlipGenerator extends Generator
    ###
    Класс, представляющий генератор id для блипов.
    ###
    constructor: () ->
        @_sequencerId = 'seq_blip_id'
        @_typePrefix = 'b'
        super()

    _getParts: (waveId, sourceId) ->
        parts = super(sourceId)
        parts.splice(2, 0, IdUtils.parseId(waveId).id)
        return parts

module.exports.BlipGenerator = new BlipGenerator()
