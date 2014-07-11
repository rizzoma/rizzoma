var couchapp = require('couchapp');

doc = {
    _id: "_design/waves_by_creation_date",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || doc.type != 'blip') return;
        if(!doc.waveId) return;
        if(!doc.isContainer) return;
        emit(doc.contentTimestamp, doc.waveId);
    }
};

module.exports = doc;
