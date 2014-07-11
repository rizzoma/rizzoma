{GoogleAuth, FacebookAuth, TwitterAuth, AutoAuth} = require('./model')
{PasswordAuth} = require('./password/model')
{CouchConverter} = require('../common/db/couch_converter')

class AuthCouchConverter

    _getConverterByModel: (model) ->
        if model instanceof GoogleAuth
            return GoogleAuthCouchConverter
        if model instanceof FacebookAuth
            return FacebookAuthCouchConverter
        if model instanceof TwitterAuth
            return TwitterAuthCouchConverter
        if model instanceof PasswordAuth
            return PasswordAuthCouchConverter
        if model instanceof AutoAuth
            return AutoAuthCouchConverter

    toCouch: (model) ->
        converter = new (@_getConverterByModel(model))
        return converter.toCouch(model)

    _getConverterByDoc: (doc) ->
        type = doc._id.split('_')[0]
        if type is 'google'
            return GoogleAuthCouchConverter
        if type is 'facebook'
            return FacebookAuthCouchConverter
        if type is 'twitter'
            return TwitterAuthCouchConverter
        if type is 'password'
            return PasswordAuthCouchConverter
        if type is 'auto'
            return AutoAuthCouchConverter

    toModel: (doc) ->
        converter = new (@_getConverterByDoc(doc))
        return converter.toModel(doc)

fields =
    authType: 'authType'
    authId: 'authId'
    userId: 'userId'
    email: '_email'
    name: '_name'
    avatar: '_avatar'
    timezone: '_timezone'
    userCompilationParams: '_userCompilationParams'
    alternativeEmails: '_alternativeEmails'
    extra: '_extra'

class GoogleAuthCouchConverter extends CouchConverter

    constructor: ->
        super(GoogleAuth)
        @_extendFields(fields)


class FacebookAuthCouchConverter extends CouchConverter

    constructor: ->
        super(FacebookAuth)
        @_extendFields(fields)


class TwitterAuthCouchConverter extends CouchConverter

    constructor: ->
        super(TwitterAuth)
        @_extendFields(fields)


class PasswordAuthCouchConverter extends CouchConverter

    constructor: ->
        super(PasswordAuth)
        @_extendFields(fields)

class AutoAuthCouchConverter extends CouchConverter

    constructor: ->
        super(AutoAuth)
        @_extendFields(fields)

module.exports.AuthCouchConverter = new AuthCouchConverter()