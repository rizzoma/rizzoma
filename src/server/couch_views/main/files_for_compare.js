var couchapp = require('couchapp');

doc = {
   _id: "_design/files_for_compare",
   language: "javascript",
   views: {}
};

doc.views.files_for_compare = {
    map: function(doc) {
        switch (doc.type) {
        case 'file':
            if(doc.removed)
                return;
            emit(doc._id, {type: 'file', linkNotFound: doc.linkNotFound || false});
            return;
        case 'blip':
            if (doc.removed) return;
            var content = doc.content;
            if (!content) return;
            for(var i=0; i < content.length; i++) {
                var params = content[i].params;
                if(!params) continue;
                if(params.__TYPE != 'FILE') continue;
                var id = params.__ID;
                if(!id) continue;
                emit(id, {type: 'link'});
            }
            return;
        default:
            return;
        }
    }
};

module.exports = doc;

