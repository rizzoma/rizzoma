var couchapp = require('couchapp');

doc = {
    _id: "_design/user_by_first_visit",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || (doc.type != 'user' && doc.type != 'User')) return;
        if(!doc.firstVisit) return;
        var sent = !!doc.firstVisitNotificationSent || false;
        emit([sent, doc.firstVisit], null);
    }
};

module.exports = doc;
