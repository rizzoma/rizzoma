module.exports.loggedIn = (req, res, next) ->
    ###
    Устанавливает флажок, залогинен ли пользователь.
    ###
    req.loggedIn = !!(req.user and not req.user.isAnonymous())
    next()
