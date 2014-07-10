var couchapp = require('couchapp');

doc = {
    _id: "_design/wave_by_topic_type_and_user_id",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function (doc) {
        if (doc.type != 'wave') return;
        var topicType = doc.topicType || 1;
        if (!doc.participants) return;
        for (var i=0; i<doc.participants.length; i++) {
            var participant = doc.participants[i];
            if (!participant.role) continue;
            if (participant.role == 65536) continue;
            emit([topicType, participant.id], null)
        }
    }
}

module.exports = doc;
