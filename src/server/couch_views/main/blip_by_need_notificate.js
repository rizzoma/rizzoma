var couchapp = require('couchapp');

doc = {
    _id: "_design/blip_by_need_notificate",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if(!doc.type || doc.type != 'blip') return;
        if(!doc.waveId) return;
        if(doc.removed) return;
        if(!doc.needNotificate) return;
        emit(doc.contentTimestamp, null);
    }
};

module.exports = doc;
