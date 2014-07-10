var couchapp = require('couchapp');

doc = {
    _id: "_design/imported",
    language: "javascript",
    views: {}
};

doc.views.imported_by_timestamp = {
    map: function(doc) {
        if(!doc.type || doc.type != 'WaveImportData') return;
        if(!doc.lastImportingTimestamp) return;
        emit(doc.lastImportingTimestamp, null);
    }
};

module.exports = doc;