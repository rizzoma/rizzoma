class UserUtils
    ###
    @see src/tests/server/user/test_utils.coffee
    ###

    constructor: () ->

    normalizeEmail: (email) =>
        return email if not email
        email = email.toLowerCase().trim()
        return @_normalizeGoogleEmail(email) if @isGoogleEmail(email)
        return @_normalizeFacebookEmail(email) if @isFacebookEmail(email)
        return email

    isGoogleEmail: (email) ->
        return /^.+@(googlemail|gmail).com$/.test(email)

    isFacebookEmail: (email) ->
        return /^.+@facebook.com$/.test(email)

    _normalizeGoogleEmail: (email) ->
        return @_transforEmail(email, (name, domain) ->
            domain = 'googlemail.com' if domain == 'gmail.com'
            name = name.replace(/\./g, '').replace(/\+[a-z0-9]+/g, '')
            return [name, domain]
        )

    _normalizeFacebookEmail: (email) ->
        return @_transforEmail(email, (name, domain) ->
            name = name.replace(/\./g, '').replace(/\+[a-z0-9]+/g, '')
            return [name, domain]
        )

    _transforEmail: (email, transform) ->
        ###
        Позволяет заменить имя или домен в email-адресе
        @param email: string
        @param transform(name: string, domain: string): [name: string, domain: string]
        ###
        [name, domain] = transform(email.split('@')...)
        return [name, domain].join('@')
    fixAvatarProtocol: (avatar) ->
        ###
        Для перехода на https. Меняю протокол юзерпиков.
        @see: common/db/migration
        ###
        return avatar if not avatar
        return avatar if not /^http/.test(avatar)
        return avatar if /^https:\/\//.test(avatar)
        return avatar.replace(/^http:/, 'https:') if /^http:\/\/www.google.com\/ig\/c.+/.test(avatar)
        console.warn("Unknown http avatar detected: #{avatar}")
        return avatar


module.exports.UserUtils = new UserUtils()