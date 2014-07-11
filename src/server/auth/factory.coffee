{TwitterAuth, FacebookAuth, GoogleAuth} = require('./model')
{PasswordAuth} = require('./password/model')

sources =
    'twitter': TwitterAuth
    'facebook': FacebookAuth
    'google': GoogleAuth
    'password': PasswordAuth

module.exports.authFactory = (source, sourceUser) ->
    ###
    Возвращает объект нужной реализации в зависимости от source
    ###
    return new sources[source](sourceUser)
