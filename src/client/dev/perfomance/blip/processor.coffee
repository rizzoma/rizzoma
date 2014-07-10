BlipProcessor = require('../../../blip/processor').BlipProcessor

class PerfomanceBlipProcessor extends BlipProcessor
    constructor: (args...) ->
        super(args...)
        
    _getNewBlipViewModel: (waveViewModel, self, shareDoc, container, parentBlip, isRead, waveId, timestamp) ->
        return {shareDoc:shareDoc}

module.exports.PerfomanceBlipProcessor = PerfomanceBlipProcessor