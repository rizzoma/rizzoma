module.exports.everyauthToPassportMigration = (req, res, next) ->
    ###
    Миграция для перехода на passportjs.
    Если в сессии были авторизационные данные everyauth адаптирует их для passportjs - пользователя не разлогинет.
    ###
    session = req.session
    userSessionData = session?.auth?.userId
    return next() if not session or not userSessionData or not session.passport
    session.passport.user = userSessionData
    delete session.auth
    next()
