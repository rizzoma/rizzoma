BaseError = require('../../../share/exceptions').BaseError

class DbError extends BaseError
    ###
    Ошибка при работе с DB.
    ###

module.exports.DbError = DbError
