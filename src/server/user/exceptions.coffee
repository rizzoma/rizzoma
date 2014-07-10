ExternalError = require('../common/exceptions').ExternalError

class InvalidEmail extends ExternalError
    ###
    Ошибка 'неверный формат email'.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'InvalidEmail'

class MergeError extends ExternalError
    ###
    Ошибка 'неверный формат email'.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'MergeError'

class InvalidBonusType extends ExternalError
    ###
    Ошибка 'неверный тип бонуса'.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'InvalidBonusType'

module.exports =
    InvalidEmail: InvalidEmail
    MergeError: MergeError
    InvalidBonusType: InvalidBonusType
    NOT_LOGGED_IN: 'not_logged_in'
    INVALID_CODE_FORMAT: 'invalid_code_format'
    INVALID_USER: 'invalid_user'
    INVALID_CODE: 'invalid_code'
    MERGING_NOT_REQUESTED: 'merging_not_requested'
    CODE_IS_DELAYED: 'code_is_delayed'
    MERGED_SUCCESSFUL: 'merged_successful'
    INTERNAL_MERGE_ERROR: 'internal_merge_error'

