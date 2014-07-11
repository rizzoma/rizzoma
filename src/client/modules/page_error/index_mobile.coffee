PageErrorBase = require('./').PageError
Session = require('../../session/module').Session

class PageError extends PageErrorBase
    showError: (request, args, callback) ->
        if request.args.error.code == 'wave_anonymous_permission_denied'
            return Session.setAsLoggedOut()
        super(request, args, callback)

    __logError: (error) ->
        require('../../error_logger/module_mobile').instance.logError(error)


exports.PageError = PageError
