ck = window.CoffeeKup

template = ->
    div ->
        input '.js-contact-picker-email.contact-picker-email', {type: "text", placeholder: "Enter email"}
        button '.js-contact-picker-add-participant.button.contact-picker-add-participant-button', "Add"
        div '.js-contact-picker-contacts.contact-picker-contacts', ->
            if @syncContactsInContactsContainer
                div '.js-contact-picker-sync-contacts.contact-picker-sync-contacts', ''
            else
                div '.contact-list-empty-message', ->
                    div ->
                        text 'Here you can pick your contacts'
                        br ''
                        text 'from Gmail or Facebook'
        if not @syncContactsInContactsContainer
            div '.js-contact-picker-sync-contacts.contact-picker-sync-contacts', ''

participantsTmpl = ->
    numOfLines = Math.ceil(@participants.length / @participantsStringLength)
    for i in [0...numOfLines]
        div '.participants-line', ->
            start = i * @participantsStringLength
            nextStart = (i + 1) * @participantsStringLength
            end = Math.min(nextStart, @participants.length)
            for index in [start...end]
                div '.js-contact-picker-participant.contact-picker-participant.avatar.clickable', {style: "background-image: url(#{h(@participants[index].avatar)})"}, h(@participants[index].initials)
            return if i > 0
            slotsLeft = Math.max(nextStart - end, 0)
            for index in [0...slotsLeft]
                div '.contact-picker-participant', ''

contactListTmpl = ->
    i = 0
    while i < @contacts.length
        if @contacts[i]? and @contacts[i].showed
            div '.js-contact-picker-contact-item.contact-picker-contact-item', {title: "#{h(@contacts[i].data.name)} #{h(@contacts[i].data.email)}"}, ->
                div '.contact-picker-contact-info', ->
                    div '.name', h(@contacts[i].data.name)
                    div '.js-email', "&#60;#{h(@contacts[i].data.email)}&#62;"
                div '.contact-picker-contact.avatar', {style:"background-image: url(#{h(@contacts[i].data.avatar)})"}, h(@contacts[i].data.initials)
        i += 1

module.exports =
    renderContactPicker: ck.compile(template)
    renderParticipants: ck.compile(participantsTmpl)
    renderContactList: ck.compile(contactListTmpl)
