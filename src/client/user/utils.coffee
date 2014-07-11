contactsConstants = require('../../share/contacts/constants')

exports.compareContactsByNameAndEmail = compareContactsByNameAndEmail = (a, b) ->
    aLowerName = a.name.toLowerCase()
    bLowerName = b.name.toLowerCase()
    return aLowerName.localeCompare(bLowerName) if aLowerName != bLowerName # Имя
    return a.email.toLowerCase().localeCompare(b.name.toLowerCase()) # E-mail

exports.compareContactsByParticipanceNameAndEmail = compareContactsByParticipanceNameAndEmail = (a, b) ->
    # Можете ненавидеть меня за магию, но это чертовски красиво
    return (+b.isParticipant) - (+a.isParticipant) if a.isParticipant != b.isParticipant
    compareContactsByNameAndEmail(a, b)

exports.getContactSources = (userContacts) ->
    res = {google: false, facebook: false}
    for user in userContacts
        if user.data.source == contactsConstants.SOURCE_NAME_GOOGLE
            res.google = true
        if user.data.source == contactsConstants.SOURCE_NAME_FACEBOOK
            res.facebook = true
    return res
