var couchapp = require('couchapp');

doc = {
   _id: "_design/file_size_by_user_id",
   language: "javascript",
   views: {}
};

doc.views.file_size_by_user_id = {
    map: function(doc) {
        if(!doc.type || doc.type != 'file') return;
        if(doc.removed) return;
        emit(doc.userId, doc.size);
    },
    reduce: '_sum'
};

module.exports = doc;

