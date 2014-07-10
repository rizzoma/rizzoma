ck = window.CoffeeKup
{ROLES} = require('../wave/participants/constants')

contactTmpl = ->
    data = @data[0]
    div '.avatar', style: "background-image: url(#{h(data.avatar)})", ''
    participantClass = if data.isParticipant then '.participant' else ''
    span participantClass, ->
        span '.name', h(data.name)
        span '.email', h("<#{data.email}>") if data.email

participantTmpl = ->
    input "", {type: "checkbox", checked: "checked" if @user.checked}
    div '.avatar', {style: "background-image: url(#{h(@user.data.avatar)})"}, h(@user.data.initials)
    div '.info', {title: "#{h(@user.data.name)} #{h(@user.data.email)}"}, ->
        span '.name', h(@user.data.name)
        span '.email', h("<#{@user.data.email}>") if h(@user.data.email)
    roleName = 'Default'
    for role in @roles
        continue if @user.data.roleId isnt role.id
        roleName = role.name
    span '.participant-role', roleName

renderContact = ck.compile(contactTmpl)
renderParticipant = ck.compile(participantTmpl)

exports.renderContact = (value, data) ->
    renderContact({value, data})

exports.renderParticipant = (user) ->
    renderParticipant({user, roles: ROLES})