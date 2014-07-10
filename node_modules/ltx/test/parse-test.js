var vows = require('vows'),
assert = require('assert'),
ltx = require('./../lib/index');

vows.describe('ltx').addBatch({
    'parsing': {
        'simple document': function() {
            var el = ltx.parse('<root/>');
            assert.equal(el.name, 'root');
            assert.equal(0, el.children.length);
        },
	'text with commas': function() {
	    var el = ltx.parse("<body>sa'sa'1'sasa</body>");
	    assert.equal("sa'sa'1'sasa", el.getText());
	},
        'erroneous document raises error': function() {
            assert.throws(function() {
                ltx.parse('<root></toor>');
            });
        },
        'incomplete document raises error': function() {
            assert.throws(function() {
                ltx.parse('<root>');
            });
        }
    }
}).export(module);
