ck = window.CoffeeKup

accountSetupWizardTmpl = ->
    div '.js-account-setup-wizard.account-setup-wizard', ->
        div '.steps-container', ->
            div '.account-setup-wizard-header', ->
                div '.logo', ''
                div '.text', 'Basic settings'
            div '.js-account-setup-wizard-content.account-setup-wizard-content', ->
        div '.account-setup-wizard-footer', ->
            div '.footer-container', ->
                a {target: '_blank', 'href': '/about-terms.html'}, 'Terms of use'
                a {target: '_blank', 'href': '/about-privacy.html'}, 'Privacy policy'

accountTypeSelectTmpl = ->
    if @fromEnterprise
        div '.from-enterprice', ->
            text "Thanks for submitting your request. We will contact you shortly."
            br '', ''
            text "Meanwhile, you can continue using Rizzoma with either Free or Business account."
    ul '.setup-steps', ->
        li '.active', ->
            div ''
            'Account type'
        li '.disabled', ->
            div ''
            'Team setup'
    div '.content-block', ->
        div '.account-type', ->
            div '.top-description', ->
                div '.header', ->
                    h2 'Non-commercial'
                    h3 'Personal, education'
                ul ->
                    li '50 MB upload space'
                    li 'Regular support'
                div '.plan-note', ->
                    text 'For commercial use or'
                    br '', ''
                    text 'use at your place of business choose '
                    b 'Business'
                    text ' plan'
            div '.bottom-description', ->
                div '.price', 'Free'
                button '.js-free-button.button', 'Start using'
        div '.account-type', ->
            div '.top-description', ->
                div '.recommended', ''
                div '.header', ->
                    h2 'Business'
                    h3 'Small companies'
                ul ->
                    li '10 GB upload space'
                    li 'Team topic collection'
                    li 'Team management'
                    li 'Tasks'
                    li 'Personal support'
            div '.bottom-description', ->
                div '.price', '$5 user/month'
                button '.js-business-button.button', 'Start 30-day Trial'
        div '.account-type', ->
            div '.top-description', ->
                div '.header', ->
                    h2 'Enterprise'
                    h3 'Custom solution'
                ul ->
                    li 'On-premises version'
                    li 'System integration'
            div '.bottom-description', ->
                div '.price', '$20 user/month'
                button '.js-enterprise-button.button', 'Request'

createTeamTmpl = ->
    ul '.setup-steps', ->
        li '.js-account-type-item.completed', ->
            div ''
            text 'Account type'
            br ''
            if @isBusinessTeamType
                span 'Business'
            else
                span 'Free'
        li '.active', ->
            div ''
            'Team setup'
    div ".content-block.#{if @isBusinessTeamType then 'business' else ''}", ->
        div '.company-block', ->
            if @isBusinessTeamType
                div '.js-error-text.error-text', 'required field'
                input '.js-team-name', {type: 'text', placeholder: 'Team name (required)'}
            div '.js-team-members.team-members', ->
                div '.team-member', ->
        div '.js-account-wizard-contact-picker-container.contact-picker-block', ''
        div '.js-submit-button.centered-button-block', ->
            button '.centered-button.button', if @isBusinessTeamType then 'Continue' else 'Next'

editTeamTmpl = ->
    div ".content-block.business", ->
        div '.company-block', ->
            div '.js-error-text.error-text', 'required field'
            input '.js-team-name', {type: 'text', placeholder: 'Team name', disabled: 'disabled'}
            div '.js-team-members.team-members', ->
                div '.team-member', ->
        div '.js-account-wizard-contact-picker-container.contact-picker-block', ''

businessCreateTeamTmpl = ->
    div ".content-block.business", ->
        div '.company-block', ->
            div '.js-error-text.error-text', 'required field'
            input '.js-team-name', {type: 'text', placeholder: 'Team name (required)'}
            div '.js-team-members.team-members', ->
                div '.team-member', ->
        div '.js-account-wizard-contact-picker-container.contact-picker-block', ''
        div '.js-submit-button.centered-button-block', ->
            button '.centered-button.button', 'Create'

enterpriseRequestTmpl = ->
    ul '.setup-steps', ->
        li '.js-account-type-item.completed', ->
            div ''
            text 'Account type'
            br ''
            span 'Enterprise'
        li '.active', ->
            div ''
            'Request'
    div '.content-block.enterprise', ->
        div '.form-field', ->
            input '.js-company-name', {type: 'text', placeholder: 'Company name', value: if @params.companyName then @params.companyName else ''}
            span 'required field'
        div '.form-field', ->
            input '.js-contact-email', {type: 'text', placeholder: 'Contact email', value: if @params.contactEmail then @params.contactEmail else ''}
            span 'required field'
        textarea '.js-comment', {placeholder: 'Comment'}, if @params.comment then @params.comment else ''
        div '.centered-button-block', ->
            button '.js-submit-form.centered-button.button', 'Submit form'

teamMemberTmpl = ->
    div '.team-member', ->
        div '.avatar', {style: "background-image: url(#{h(@p.avatar)})"}, h(@p.initials)
        div '.info', ->
            div '.name', {title: h(@p.name)}, h(@p.name)
            div '.js-email.email', {title: h(@p.email)}, h(@p.email)
        if window.userInfo.email != @p.email
            div '.js-remove-item.remove-item', ''

exports.renderAccountSetupWizard = ck.compile(accountSetupWizardTmpl)
exports.renderAccountTypeSelect = ck.compile(accountTypeSelectTmpl)
exports.renderCreateTeam = ck.compile(createTeamTmpl)
exports.renderEditTeam = ck.compile(editTeamTmpl)
exports.renderBusinessCreateTeam = ck.compile(businessCreateTeamTmpl)
exports.renderTeamMember = ck.compile(teamMemberTmpl)
exports.renderEnterpriseRequest = ck.compile(enterpriseRequestTmpl)