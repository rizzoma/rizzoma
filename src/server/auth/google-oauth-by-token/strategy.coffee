OAuth2Strategy = require('passport-google-oauth').OAuth2Strategy

###
Стратегия для аутотентификации по acess token-у googla-a
###
class Strategy extends OAuth2Strategy
    constructor: (options, args...) ->
        options.clientID = ' '
        options.clientSecret = ' '
        super(options, args...)
        @name = 'googleByToken'

    authenticate: (req) ->
        accessToken = req.query.accessToken
        @_loadUserProfile(accessToken, (err, profile) =>
            return @error(err) if err
            verified = (err, user, info) =>
                return @error(err) if  err
                return @fail(info) if not user
                @success(user, info)
            if @_passReqToCallback
                arity = @_verify.length
                if arity == 6
                    @_verify(req, accessToken, null, {}, profile, verified)
                else
                    @_verify(req, accessToken, null, profile, verified)
            else
                arity = self._verify.length
                if arity == 5
                    @_verify(accessToken, null, {}, profile, verified);
                else
                    @_verify(accessToken, null, profile, verified);
        )

module.exports = Strategy
