renderAccountTypeSelect = require('./template').renderAccountTypeSelect
MicroEvent = require('../utils/microevent')


class AccountTypeSelect
    constructor: (@_$container) ->
        @renderAndInit()

    _init: ->
        @_$container.find('.js-business-button').on 'click', =>
            @emit 'businessAccountClick'
        @_$container.find('.js-enterprise-button').on 'click', =>
            @emit 'enterpriseAccountClick'
        @_$container.find('.js-free-button').on 'click', =>
            @emit 'freeAccountClick'

    renderAndInit: (fromEnterprise) ->
        @_$container.append(renderAccountTypeSelect({fromEnterprise}))
        @_init()


MicroEvent.mixin(AccountTypeSelect)
exports.AccountTypeSelect = AccountTypeSelect