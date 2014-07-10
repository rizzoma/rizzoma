ExternalError = require('../common/exceptions').ExternalError

class ImportError extends ExternalError
    constructor: (message, data) ->
        @data = data
        super(message)
        @name = 'ImportError'

class SourceParseImportError extends ImportError
    constructor: (args...) ->
        super(args...)
        @name = 'SourceParseImportError'
        
class WaveAlreadyImportedImportError extends ImportError
    constructor: (args...) ->
        super(args...)
        @name = 'WaveAlreadyImportedImportError'    

class WaveImportingInProcessImportError extends ImportError
    constructor: (args...) ->
        super(args...)
        @name = 'WaveImportingInProcessImportError'    
        
module.exports =
    ImportError: ImportError
    SourceParseImportError: SourceParseImportError
    WaveAlreadyImportedImportError: WaveAlreadyImportedImportError
    WaveImportingInProcessImportError: WaveImportingInProcessImportError