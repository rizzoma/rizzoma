ExternalError = require('../common/exceptions').ExternalError
{WAVE_PERMISSION_DENIED_ERROR_CODE,
 WAVE_DOCUMENT_DOES_NOT_EXISTS_ERROR_CODE,
 WAVE_ANONYMOUS_PERMISSION_DENIED_ERROR_CODE
} = require('../../share/constants')

class WaveError extends ExternalError
    ###
    Ошибка при работе с волной.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'WaveError'

module.exports =
    WaveError: WaveError
    WAVE_PERMISSION_DENIED : WAVE_PERMISSION_DENIED_ERROR_CODE
    WAVE_ANONYMOUS_PERMISSION_DENIED : WAVE_ANONYMOUS_PERMISSION_DENIED_ERROR_CODE
    WAVE_BLOCKED_USER_PERMISSION_DENIED: 'wave_blocked_user_permission_denied'
    WAVE_DOCUMENT_DOES_NOT_EXISTS : WAVE_DOCUMENT_DOES_NOT_EXISTS_ERROR_CODE
    WAVE_PARTICIPANT_ALREADY_IN : 'wave_participant_already_in'
    WAVE_PARTICIPANT_NOT_IN : 'wave_participant_not_in'
    WAVE_NO_ANOTHER_MODERATOR: 'wave_no_another_moderator'
    WAVE_INVALID_PARAM_VALUE: 'wave_invalid_param_value'
