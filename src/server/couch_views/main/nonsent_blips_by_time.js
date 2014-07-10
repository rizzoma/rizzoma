var couchapp = require('couchapp');

doc = {
    _id: "_design/nonsent_blips_by_time",
    language: "javascript",
    views: {}
};

doc.views.get = {
    map: function(doc) {
        if (!doc.type || doc.type != 'blip') return;
        if (!doc.waveId) return;
        if (!doc.content) return;
        if (doc.removed) return;
        var chechForTask = function(block, doc) {
            return !!(block.params.__TYPE == 'TASK' && !block.params.lastSent);
        };
        var checkForMessage = function(block, doc) {
            if(doc.pluginData && doc.pluginData.message && doc.pluginData.message.lastSent) return;
            if (block.params.__TYPE != 'RECIPIENT') return;
            return true;
        };
        var content = doc.content;
        for (var i = content.length - 1; i >= 0; i--) {
            var block = content[i];
            if(chechForTask(block, doc) || checkForMessage(block, doc)) {
                return emit(doc.contentTimestamp, null);
            }
        }
    }
};

module.exports = doc;
