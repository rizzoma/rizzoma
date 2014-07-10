renderAccountSetupWizard = require('./template').renderAccountSetupWizard
AccountTypeSelect = require('./account_type_select').AccountTypeSelect
{CreateTeam, BUSINESS_PANEL_TYPE, FREE_PANEL_TYPE} = require('./create_team')
{EnterpriseRequest, ENTERPRISE_PANEL_TYPE} = require('./enterprise_request')
MicroEvent = require('../utils/microevent')


class AccountSetupWizard
    constructor: ->
        @_accountSetupProcessor = require('./processor').instance
        @_topicId = if window.welcomeWaves.length > 0 then window.welcomeWaves[0].waveId else null
        @_createDom()

    _createDom: ->
        $(document.body).append(renderAccountSetupWizard())
        @_$container = $('.js-account-setup-wizard-content')
        @_accountTypeSelect = new AccountTypeSelect(@_$container)
        @_panels = {}
        @_accountTypeSelect.on 'freeAccountClick', =>
            _gaq.push(['_trackEvent', 'Monetization', 'Select plan', 'Free'])
            @_accountSetupProcessor.setAccountTypeSelected(->)
            if @_topicId and window.welcomeTopicJustCreated
                @_getOrCreateTeamAccountPanel(FREE_PANEL_TYPE).renderAndInit()
            else
                @emit('closeAndOpenTopic')
        @_accountTypeSelect.on 'businessAccountClick', =>
            _gaq.push(['_trackEvent', 'Monetization', 'Select plan', 'Business'])
            @_accountSetupProcessor.setAccountTypeSelected(->)
            @_getOrCreateTeamAccountPanel(BUSINESS_PANEL_TYPE).renderAndInit()
        @_accountTypeSelect.on 'enterpriseAccountClick', =>
            _gaq.push(['_trackEvent', 'Monetization', 'Select plan', 'Enterprise'])
            @_accountSetupProcessor.setAccountTypeSelected(->)
            @_getOrCreateTeamAccountPanel(ENTERPRISE_PANEL_TYPE).renderAndInit()
        _gaq.push(['_trackEvent', 'Monetization', 'Show plans'])

    _getOrCreateTeamAccountPanel: (teamType) =>
        return if !(teamType in [BUSINESS_PANEL_TYPE, FREE_PANEL_TYPE, ENTERPRISE_PANEL_TYPE])
        return @_panels[teamType] if @_panels[teamType]?
        if teamType in [BUSINESS_PANEL_TYPE, FREE_PANEL_TYPE]
            @_panels[teamType] = new CreateTeam(@_$container, teamType, @, @_topicId)
        if teamType is ENTERPRISE_PANEL_TYPE
            @_panels[teamType] = new EnterpriseRequest(@_$container)
            @_panels[teamType].on 'submit', @_submitEnterpriseRequest
        @_panels[teamType].on 'returnToAccountSelect', @_returnToAccountSelect
        return @_panels[teamType]

    _submitEnterpriseRequest: (companyName, email, comment) =>
        @_accountSetupProcessor.sendEnterpriseRequest companyName, email, comment, (err) =>
            console.error err if err
            @_returnToAccountSelect(true)

    _returnToAccountSelect: (fromEnterprise) =>
        @_$container.empty()
        @_accountTypeSelect.renderAndInit(fromEnterprise)

    destroy: ->
        for _, panel of @_panels
            panel.destroy() if panel?
        $('.js-account-setup-wizard').remove()


MicroEvent.mixin(AccountSetupWizard)
exports.AccountSetupWizard = AccountSetupWizard