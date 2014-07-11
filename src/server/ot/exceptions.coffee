BaseError = require('../../share/exceptions').BaseError

class OtError extends BaseError
    ###
    Ошибка при работе с OT.
    ###

module.exports =
    OtError: OtError
    OP_ALREADY_APPLIED: 'OP_ALREADY_APPLIED'