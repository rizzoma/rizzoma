var couchapp = require('couchapp');

doc = {
   _id: "_design/read_blip_count_by_wave_id_and_participant_id_2",
   language: "javascript",
   views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || doc.type != 'blip') return;
        var waveId = doc.waveId;
        var version = doc.contentVersion;
        var readers = doc.readers;
	    if(doc.removed) return;
        if(doc.isContainer) return;
        if(!waveId || !readers || version === undefined) return;
        for(var readerId in readers) {
            if(version != readers[readerId]) continue;
            emit([waveId, readerId], null);
        }
    },
    reduce: "_count"
}

module.exports = doc;
