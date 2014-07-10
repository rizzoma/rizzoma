var couchapp = require('couchapp');

doc = {
    _id: "_design/user_by_notification_id",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if(!doc.type || doc.type != 'user') return;
        if (!doc.notification || !doc.notification.id) return;
        emit(doc.notification.id, null);
    }
};

module.exports = doc;
