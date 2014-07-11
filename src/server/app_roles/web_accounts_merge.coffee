passport = require('passport')
MergeController = require('../user/merge_controller').MergeController
Conf = require('../conf').Conf
app = require('./web_base').app
AuthUtils = require('../utils/auth_utils').AuthUtils

EMAIL_CONFIRM_CALLBACK_URL = new RegExp("#{Conf.get('accountsMerge').emailConfirmCallbackUrl}$")
OAUTH_CONFIRM_URL = Conf.get('accountsMerge').oauthConfirmUrl
OAUTH_CONFIRM_CALLBACK_URL = Conf.get('accountsMerge').oauthConfirmCallbackUrl

WAVE_URL = Conf.getWaveUrl()
MERGE_STRATEGY_NAME_PREFIX = require('../user/constants').MERGE_STRATEGY_NAME_PREFIX

successTemplate = Conf.getTemplate().compileFile('accounts_merge_oauth.html')
errorTemplate = Conf.getTemplate().compileFile('accounts_merge_oauth_error.html')

{
    MergeError
    NOT_LOGGED_IN
    INTERNAL_MERGE_ERROR
    MERGED_SUCCESSFUL
} = require('../user/exceptions')

redirect = (res, err) ->
    getCode = (err) ->
        return MERGED_SUCCESSFUL if not err
        return if err instanceof MergeError then err.code else INTERNAL_MERGE_ERROR
    res.redirect("#{WAVE_URL}?notice=#{getCode(err)}")

app.get(EMAIL_CONFIRM_CALLBACK_URL, (req, res) ->
    return redirect(res, new MergeError('You should be logged in to merge accounts', NOT_LOGGED_IN)) if not req.loggedIn
    user = req.user
    digest = req.param('digest')
    MergeController.mergeByDigest(user, digest, (err, primaryUser) ->
        return redirect(res, err) if err
        AuthUtils.setSessionUserData(req.session, primaryUser)
        redirect(res)
    )
)

_getStrategyName = (source) ->
    return "#{MERGE_STRATEGY_NAME_PREFIX}#{source}"

_getSource = (req) ->
    return  req.params[0]

_errorRedirect = (req, res, err) ->
    res.end(errorTemplate.render({message: err.message}))

_successRedirect = (req, res, profile) ->
    code = req.session.mergingValidationData.code
    res.end(successTemplate.render({profile, code}))

app.get(OAUTH_CONFIRM_URL, (req, res, next) ->
    source = _getSource(req)
    params = {}
    scope = Conf.getAuthSourceConf(source).scope
    params.scope = scope if scope
    passport.authenticate(_getStrategyName(source), params)(req, res, next)
)

app.get(OAUTH_CONFIRM_CALLBACK_URL, (req, res) ->
    source = _getSource(req)
    passport.authenticate(_getStrategyName(source), {session: false}, (err, profile, info) ->
        return _errorRedirect(req, res, info) if not profile
        _successRedirect(req, res, profile)
    )(req, res, (err) ->
        return _errorRedirect(req, res, err)
    )
)