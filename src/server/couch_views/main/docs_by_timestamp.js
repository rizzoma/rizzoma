var couchapp = require('couchapp');

doc = {
   _id: "_design/search",
   language: "javascript",
   views: {}
};

doc.views.docs_by_timestamp = {
    map: function(doc) {
          if(!doc.type || (doc.type != 'wave' && doc.type != 'blip')) return;
          var timestamp = doc.contentTimestamp;
          if(!timestamp) return;
          emit(timestamp, null);
        }
    };

module.exports = doc;
