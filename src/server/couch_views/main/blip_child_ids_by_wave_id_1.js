var couchapp = require('couchapp');

doc = {
    _id: "_design/blip_child_ids_by_wave_id_1",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if(!doc.type || doc.type != 'blip') return;
        if(!doc.waveId) return;
        var childs = [];
        var removed = doc.removed;
        var content = doc.content;
        if(!content) return;
        for(var i=content.length-1; i>=0; i--) {
            var params = content[i].params;
            if(!params) continue;
            if(params.__TYPE != 'BLIP') continue;
            var id = params.__ID;
            if(!id) continue;
            childs.push(id);
        }
        var timestamp =  removed ? doc.contentTimestamp : {};
        emit([doc.waveId, timestamp], childs);
    }
};

module.exports = doc;
