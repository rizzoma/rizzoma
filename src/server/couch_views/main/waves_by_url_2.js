var couchapp = require('couchapp');

doc = {
   _id: "_design/waves_by_url_2",
   language: "javascript",
   views: {}
};

doc.views.get = {
    map: function (doc) {
        if(!doc.type || doc.type != 'wave') return;
        var urls = doc.urls
        if(!urls) return;
        for(var i=0; i<urls.length; i++) {
            emit(['wave', urls[i]], null);
        }
        if(!doc.gDriveId) return;
        emit(['gDrive', doc.gDriveId], null);
    }
}

module.exports = doc;
