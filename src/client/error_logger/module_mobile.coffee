ErrorLoggerBase = require('./module').ErrorLogger

class ErrorLogger extends ErrorLoggerBase
    _getErrorData: (e) ->
        data = super(e)
        data.isMobile = true if data?
        return data

module.exports = {ErrorLogger}