ExternalError = require('../common/exceptions').ExternalError

class StoreError extends ExternalError
    ###
    Ошибка при рабоде с магазином.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'StoreError'

module.exports.StoreError = StoreError
