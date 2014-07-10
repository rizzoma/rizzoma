var couchapp = require('couchapp');

doc = {
    _id: "_design/user_by_digest_3",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || (doc.type != 'user' && doc.type != 'User')) return;
        if(!doc.firstVisit) return;
        if(doc.mergedWith) return;
        var lastDigestSent = doc.lastDigestSent || 0;
        var lastVisit = doc.lastActivity || doc.lastVisit || 0;
        if(doc.notification && (doc.notification.state == 'deny-all'
            || (doc.notification._settings
                && doc.notification._settings.weekly_changes_digest
                && doc.notification._settings.weekly_changes_digest.smtp == false
                && (!doc.notification._settings.daily_changes_digest
                    || doc.notification._settings.daily_changes_digest.smtp != true))))
            return;
        var digestType = 'weekly';
        if (doc.notification
            && doc.notification._settings
            && doc.notification._settings.weekly_changes_digest
            && doc.notification._settings.weekly_changes_digest.smtp == false
            && doc.notification._settings.daily_changes_digest
            && doc.notification._settings.daily_changes_digest.smtp == true)
            digestType = 'daily';
        emit([digestType, Math.max(lastVisit, lastDigestSent)], null);
    }
};

module.exports = doc;
