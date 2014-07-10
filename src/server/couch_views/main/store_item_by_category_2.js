var couchapp = require('couchapp');

doc = {
    _id: "_design/store_item_by_category_2",
    language: "javascript",
    views: {},
    lists: {},
    shows: {}
}

doc.views.get = {
    map: function(doc) {
        if(doc.type != 'store_item') return;
        var category = doc.category;
        var state = doc.state;
        var weight = doc.weight || {};
        if(!category || !state) return;
        emit([state, weight, category], null);
    }
};

module.exports = doc