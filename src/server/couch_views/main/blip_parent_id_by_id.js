var couchapp = require('couchapp');

doc = {
    _id: "_design/blip_parent_id_by_id",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if(!doc.type || doc.type != 'blip') return;
        if(!doc.waveId) return;
        if(doc.removed) return;
        var childs = [], content = doc.content;
        if(!content) return;
        for(var i = content.length - 1; i >= 0; i--) {
            var params = content[i].params;
            if(!params || params.__TYPE != 'BLIP') continue;
            var id = params.__ID;
            if(!id) continue;
            if (params.__THREAD_ID
                && content[i-1]
                && content[i-1].params
                && content[i-1].params.__TYPE == 'BLIP'
                && (content[i-1].params.__ID == params.__THREAD_ID
                    || content[i-1].params.__THREAD_ID == params.__THREAD_ID)
            ) {
                emit(id, content[i-1].params.__ID);
            } else {
                emit(id, doc._id);
            }
        }
    }
};

module.exports = doc;
