var couchapp = require('couchapp');

doc = {
    _id: "_design/user_by_email_1",
    language: "javascript",
    views: {},
    lists: {},
    shows: {}
}

doc.views.get = {
    map: function(doc) {
        if (!doc.type || (doc.type != 'user' && doc.type != 'User')) return;
        if(doc.mergedWith) return;
        var emails = doc.normalizedEmails || [];
        if (!emails.length && doc.normalizedEmail) {
            emails.push(doc.normalizedEmail);
        }
        for (var i = 0; i < emails.length; i++) {
            emit(emails[i], null);
        }
    }
};

module.exports = doc