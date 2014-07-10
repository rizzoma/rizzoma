var couchapp = require('couchapp');

doc = {
   _id: "_design/blip_version_by_id",
   language: "javascript",
   views: {}
};

doc.views.get = {
    map: function(doc) {
          if(!doc.type || doc.type != 'blip') return;
          var version = doc.version
          if(version == undefined) return;
          emit(doc._id, version);
        }
    };

module.exports = doc;
