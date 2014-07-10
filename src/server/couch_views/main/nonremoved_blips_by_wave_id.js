var couchapp = require('couchapp');

doc = {
   _id: "_design/nonremoved_blips_by_wave_id",
   language: "javascript",
   views: {}
};

doc.views.get = {
    map: function(doc) {
          if(!doc.type || doc.type != 'blip') return;
          if(!doc.waveId) return;
          if(doc.removed) return;
          emit(doc.waveId, null);
        }
    };

module.exports = doc;
