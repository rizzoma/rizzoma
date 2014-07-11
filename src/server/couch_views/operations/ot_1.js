var couchapp = require('couchapp');

doc = {
   _id: "_design/ot_1",
   language: "javascript",
   views: {},
   lists: {},
   shows: {}
}

doc.views.ot_operations = {
    map: function(doc) {
          if (doc.type != 'operation') return;
          var docId = doc.docName || doc.docId
          var version = doc.version
          if (!docId) return;
          if (version === undefined) return;
          emit([docId, version], null);
      }        
    }

module.exports = doc