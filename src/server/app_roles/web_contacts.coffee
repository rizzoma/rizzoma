###
Роль для запуска страницы, запрашивающей права и получающей из Google контакты пользователя
###
async = require('async')
accLangParser = require('acc-lang-parser')
app = require('./web_base').app
Conf = require('../conf').Conf
contactsConf = Conf.get('contacts')
logger = Conf.getLogger('contacts')
{serveStatic} = require('../utils/express')
ContactsController = require('../contacts/controller').ContactsController

BASE_URL = Conf.get('baseUrl')
UPDATE_URL = contactsConf.updateUrl
REDIRECT_URI = contactsConf.redirectUri
INTERNAL_AVATARS_URL = contactsConf.internalAvatarsUrl
AVATARS_PATH = contactsConf.avatarsPath

successTemplate = Conf.getTemplate().compileFile('contacts_updated.html')
errorTemplate = Conf.getTemplate().compileFile('contacts_update_error.html')
renderTemplate = (template, context) ->
    ###
    Рендерит шаблон (ошибка или удачное обновление).
    @param tamplate: object
    @param context: object
    ###
    try
        return template.render(context)
    catch e
        logger.error(e)
        return "Error"

#Раздаем аватарки.
app.get new RegExp("#{INTERNAL_AVATARS_URL}(.*)"), serveStatic(AVATARS_PATH)

_getUserAndSource = (req, res) ->
    ###
    Хэлпер для получения источника и пользователя. В случае ошибки завершит запрос
    @returns [UserModel, string]
    ###
    if not req.loggedIn
        res.end(renderTemplate(errorTemplate, {message: 'Should be logged in to update contact list'}))
        return [null, null]
    return [req.user, req.params[0]]

app.get(UPDATE_URL, (req, res) ->
    ###
    Обработчик запроса обновления контактов. Здесь только инициируем получение токена.
    Остальная логика в обработчике REDIRECT_URI.
    ###
    [user, source] = _getUserAndSource(req, res)
    return if not user
    ContactsController.getAccessToken(source, req, res)
)

app.get '/contacts/update/', (req, res) ->
    ###
    Редирект на всякий случай (legacy),
    ###
    res.redirect('/contacts/google/update/')

app.get(REDIRECT_URI, (req, res) ->
    ###
    Обработчик запроса от провайдера авторизации. Здесь у нас есть код, но еще нет токена - надо получить и работать дальше.
    ###
    [user, source] = _getUserAndSource(req, res)
    return if not user
    tasks = [
        async.apply(ContactsController.onAuthCodeGot, source, req, res)
        (accessToken, callback) ->
            ContactsController.updateContacts(source, accessToken, user, _getLocale(req), (err, contacts) ->
                return callback(err) if err
                callback(null, contacts)
            )
        (contacts, callback) ->
            res.end(renderTemplate(successTemplate, {contacts: contacts, baseUrl: BASE_URL}))
            callback()
    ]
    async.waterfall(tasks, (err) ->
        return if not err
        logger.warn("Got error when updating user #{user.id} contacts", err)
        if err == 'access_denied'
            message = 'You should allow access to synchronize contact list.'
        else
            message = 'Update error. Please try again.'
        res.end(renderTemplate(errorTemplate, {message: message}))
    )
)

_getLocale = (req) ->
    acceptLanguage = req.headers['accept-language']
    return if not acceptLanguage
    acceptLanguage = accLangParser.extractFirstLang(acceptLanguage)
    return "#{acceptLanguage.language}_#{acceptLanguage.locale}"
