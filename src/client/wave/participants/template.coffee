ck = window.CoffeeKup

participantTmpl = ->
    span '.wave-participant.avatar', {style:"background-image: url(#{h(@avatar)})"}, h(@initials)

participantsContainerTmpl = ->
    div '.js-participant-container.participants', {style: 'width: 210px;'}, ''
    buttonParams = {title: 'Manage topic members'}
    button '.js-show-more-participants.show-more-participants', buttonParams, ->
        span '', ''
        div '.more-participants-image', ''
    div '.clearer', ''

manageParticipantsFormTmpl = ->
    className = '.manage-participants-form'
    className += '.anonymous' if @isAnonymous
    div className, ->
        input '.js-showing-participants-id.showing-participants-id', {type: "text", value: ""}
        br '', ''
        div '.js-selected-count.selected-count', ->
            input '#select-all-participants.js-select-all-checkboxes.select-all-checkboxes', {type: "checkbox"}
            label for: 'select-all-participants', ->
                span '0'
                text ' topic members selected'
        div '.js-autocomplete-results.autocomplete-results', ''
        div '.js-control-container.control-container', ->
            select '.button-like.js-participant-role-select', ->
                option {selected: "selected", value: '-1'}, 'Select role'
                for role in @roles when role.id isnt @skipRole
                    option {value: role.id}, role.name
            button '.js-create-topic-for-selected', {title: "Create new topic with selected members"}, 'New topic with selected'
            button '.js-remove-selected.remove-selected', {title: "Delete selected members"}, 'Remove'
        return unless @gDriveShareUrl
        hr ''
        div ->
            span 'This topic was shared via Google Drive '
            a 'button', {target: '_blank', href: h(@gDriveShareUrl)}, 'Settings'

userBottomPopupTmpl = ->
    div '', ->
        if @roles
            select '.js-role-select.role-select.button-like', ->
                for role in @roles
                    params = {value: role.id}
                    if role.id is @roleId
                        params.selected = 'selected'
                    else if role.id is @skipRole
                        continue
                    option params, role.name
        params = {}
        if not @canRemove
            params.disabled = 'disabled'
        button '.js-delete-from-wave.delete-from-wave', params, 'Remove'
        div '.clearer', ''

exports.renderBottomPopup = ck.compile(userBottomPopupTmpl)

exports.renderParticipant = ck.compile(participantTmpl)

exports.renderParticipantsContainer = ck.compile(participantsContainerTmpl)

exports.renderManageParticipantsForm = ck.compile(manageParticipantsFormTmpl)