Generator = require('../common/generator').Generator

class WaveGenerator extends Generator
    ###
    Класс, представляющий генератор id для волн.
    ###
    constructor: () ->
        @_sequencerId = 'seq_wave_id'
        @_typePrefix = 'w'
        super()
        
module.exports.WaveGenerator = new WaveGenerator()
