ExternalError = require('../common/exceptions').ExternalError

class BlipError extends ExternalError
    ###
    Ошибка при работе с блипом.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'BlipError'

module.exports =
    BlipError: BlipError
    BLIP_DOCUMENT_DOES_NOT_EXISTS : 'blip_document_does_not_exists'
    BLIP_PERMISSION_DENIED : 'blip_permission_denied'
    BLIP_OP_DENIED : 'blip_op_denied'
    INVALID_ENQUIRY_BLIP_ID: 'invalid_enquiry_blip_id'