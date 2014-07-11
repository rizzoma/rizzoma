var couchapp = require('couchapp');

doc = {
    _id: "_design/waves_by_container_blip_id",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if(!doc.type || doc.type != 'wave') return;
        if(doc.containerBlipId) return;
        emit(doc._id, null);
    }
};

module.exports = doc;
