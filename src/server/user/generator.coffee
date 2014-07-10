Generator = require('../common/generator').Generator

class UserGenerator extends Generator
    ###
    Класс, представляющий генератор id для пользователей.
    ###
    constructor: () ->
        @_sequencerId = 'seq_user_id'
        @_typePrefix = 'u'
        super()

module.exports.UserGenerator= new UserGenerator()
