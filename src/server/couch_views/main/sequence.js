var couchapp = require('couchapp');

doc = {
   _id: "_design/sequence",
   language: "javascript",
   updates: {}
};

doc.updates = {
    increment: function(doc, req) {
        var seq = doc.seq;
        var offset = parseInt(req.query.offset)
        if(isNaN(offset)) {
            offset = 1;
        }
        doc.seq += offset;
        var resp = {
            'start': seq+1,
            'end': doc.seq
        };
        return [doc, JSON.stringify(resp)];
    }
};

module.exports = doc;

