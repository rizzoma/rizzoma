var couchapp = require('couchapp');

doc = {
   _id: "_design/blip",
   language: "javascript",
   views: {}
};

doc.views.blips_by_wave_id = {
    map: function(doc) {
          if(!doc.type || doc.type != 'blip') return;
          if(!doc.waveId) return;
          emit(doc.waveId, null);
        }
    };

module.exports = doc;
