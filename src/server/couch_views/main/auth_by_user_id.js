var couchapp = require('couchapp');

doc = {
    _id: "_design/auth_by_user_id",
    language: "javascript",
    views: {},
    lists: {},
    shows: {}
}

doc.views.get = {
    map: function(doc) {
        if (!doc.type || doc.type.toLowerCase() != 'auth') {
            return;
        }
        emit(doc.userId);
    }
};

module.exports = doc