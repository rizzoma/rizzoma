{BlipProcessorBase} = require('./processor_base')
{BlipViewModel} = require('./index_mobile')

class BlipProcessor extends BlipProcessorBase

    __constructBlip: (blipData, waveViewModel, container, parentBlip) ->
        ###
        @override
        ###
        super(blipData, waveViewModel, container, parentBlip, BlipViewModel)

module.exports.BlipProcessor = BlipProcessor
module.exports.instance = null
