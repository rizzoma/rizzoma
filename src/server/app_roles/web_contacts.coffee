###
Role for contacts: pages for ask for Google/Facebook Contacts API access, retrieve contacts, process avatars requests.
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
    Render template (error or successful update).
    @param template: object
    @param context: object
    ###
    try
        return template.render(context)
    catch e
        logger.error(e)
        return "Error"

# Serve requests to avatar files (for downloaded Google contacts' avatars)
app.get new RegExp("#{INTERNAL_AVATARS_URL}(.*)"), serveStatic(AVATARS_PATH)

_getUserAndSource = (req, res) ->
    ###
    Helper to get signed in user and contacts source for request.
    @returns [UserModel, string]
    ###
    if not req.loggedIn
        res.end(renderTemplate(errorTemplate, {message: 'Should be logged in to update contact list'}))
        return [null, null]
    return [req.user, req.params[0]]

app.get(UPDATE_URL, (req, res) ->
    ###
    Start page for contacts update. Initialize API access request.
    Next steps are in REDIRECT_URI page handler.
    ###
    [user, source] = _getUserAndSource(req, res)
    return if not user
    ContactsController.getAccessToken(source, req, res)
)

app.get '/contacts/update/', (req, res) ->
    ###
    Legacy redirect,
    ###
    res.redirect('/contacts/google/update/')

app.get(REDIRECT_URI, (req, res) ->
    ###
    Process API access request result: get accessToken from "code", retrieve contacts and return them to user.
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
