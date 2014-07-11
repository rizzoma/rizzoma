var couchapp = require('couchapp');

doc = {
    _id: "_design/tags_by_blip_id",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || doc.type != 'blip') return;
        if(doc.removed) return;
        var waveId = doc.waveId;
        if(!waveId) return;
        for (var i = 0; i < doc.content.length; i++) {
            var fr = doc.content[i];
            if (fr.params.__TYPE == 'TAG')
            emit(doc._id, fr.params.__TAG);
        }
    }
}

module.exports = doc;


