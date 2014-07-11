var couchapp = require('couchapp');

doc = {
   _id: "_design/total_blip_count_by_wave_id_2",
   language: "javascript",
   views: {}
};

doc.views.get = {
    map: function (doc) {
            if(!doc.type || doc.type != 'blip') return;
            if(doc.removed) return;
            if(doc.isContainer) return;
            var waveId = doc.waveId;
            if(!waveId) return;
            emit(waveId, null);
        },
    reduce: "_count"
}

module.exports = doc;
