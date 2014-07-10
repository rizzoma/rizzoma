{User} = require('../../user/models')
{LocalStorage} = require('../../utils/localStorage')
{trackTopicCreatedAndUserAdded} = require('../../analytics/ping')

module.exports.trackParticipantAddition = (label, userData) ->
    user = new User(null, userData.email, userData.name, userData.avatar)
    if user.isNewUser()
        _gaq.push(['_trackEvent', 'Topic participants', "Add participant new", label, 1])
        mixpanel.track("Add participant", {"participant type": "new", "added via": label, "count":1, "count new":1, "count existing":0})
        trackTopicCreatedAndUserAdded(1, 0)
        LocalStorage.incUsersAdded()
    else
        _gaq.push(['_trackEvent', 'Topic participants', "Add participant existing", label, 1])
        mixpanel.track("Add participant", {"participant type": "existing", "added via": label, "count":1, "count new":0, "count existing":1})
