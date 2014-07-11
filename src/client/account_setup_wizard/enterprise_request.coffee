{renderEnterpriseRequest} = require('./template')
MicroEvent = require('../utils/microevent')
{isEmail} = require('../../share/utils/string')


ENTERPRISE_PANEL_TYPE = 'ENTERPRISE'

class EnterpriseRequest
    constructor: (@_$container) ->
        @_params = {}

    _init: ->
        @_$container.find('.js-account-type-item').on 'click', =>
            @_saveState()
            @emit 'returnToAccountSelect'
        @_$container.find('.js-submit-form').on 'click', @_validateAndSubmitForm
        @_$container.on 'keydown', 'input', (e) =>
            return if e.keyCode != 13
            @_validateAndSubmitForm()
        @_$companyNameField = @_$container.find('.js-company-name')
        window.setTimeout =>
            @_$companyNameField.focus()
        , 0
        @_$contactEmailField = @_$container.find('.js-contact-email')
        @_$commentField = @_$container.find('.js-comment')

    _animateField: ($field) ->
        $field.animate({opacity: 1}, 500, ->
            $field.animate({opacity: 0.4}, 500)
        )

    _validateAndSubmitForm: =>
        @_$companyNameField.parent().removeClass('error')
        @_$contactEmailField.parent().removeClass('error')
        @_$companyNameField.data('error', null)
        @_$contactEmailField.data('error', null)
        if @_$companyNameField.val().length == 0
            @_$companyNameField.parent().addClass('error')
            @_$companyNameField.data('error', true)
            @_animateField(@_$companyNameField.parent().find('span'))
        if @_$contactEmailField.val().length == 0
            @_$contactEmailField.parent().addClass('error')
            @_$contactEmailField.data('error', true)
            @_animateField(@_$contactEmailField.parent().find('span'))
        if !@_$contactEmailField.data('error') and !isEmail(@_$contactEmailField.val())
            @_$contactEmailField.parent().find('span').text('Invalid email')
            @_$contactEmailField.data('error', true)
            @_$contactEmailField.parent().addClass('error')
            @_animateField(@_$contactEmailField.parent().find('span'))
        return if @_$contactEmailField.data('error') or @_$companyNameField.data('error')
        _gaq.push(['_trackEvent', 'Monetization', 'Submit enterprise request'])
        @emit('submit', @_$companyNameField.val(), @_$contactEmailField.val(), @_$commentField.val())

    renderAndInit: ->
        @_$container.empty()
        @_$container.append(renderEnterpriseRequest({params: @_params}))
        @_$container.find('input, textarea').placeholder?()
        @_init()

    _saveState: ->
        @_params =
            companyName: @_$companyNameField.val()
            contactEmail: @_$contactEmailField.val()
            comment: @_$commentField.val()

    destroy: ->
        @_$container.empty()
        delete @_$container
        delete @_params


MicroEvent.mixin(EnterpriseRequest)
module.exports = {EnterpriseRequest, ENTERPRISE_PANEL_TYPE}