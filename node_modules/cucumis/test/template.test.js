_ = require('underscore');
var fs = require('fs'),
    path = require('path');

_.templateSettings = {
  interpolate : /\{\{(.+?)\}\}/g
};

module.exports = require('expressobdd')({
	'templating': {
		'it should be able to use underscore': function() {
			_.should.not.equal(undefined);
		},
		'it should be able to use a simple template': function() {
			var out = _.template('Hello {{name}}', {name: 'Fred'});
			out.should.eql('Hello Fred');
		},
		'it should be able to read a template from a file': function() {
			fs.readFile(path.join(__dirname, 'fixtures/test.js.tpl'), function(err, data) {
				if (err) throw err;

				var out = _.template(data.toString(), {name: 'Fred'});
				out.should.eql('Hello Fred,\n\nThis is a cool template\n');
			});
		},
		'it shoud be able to compile a template': function() {
			var tpl = _.template('Hello {{name}}');
			var out = tpl({name: 'Fred'});
			out.should.eql('Hello Fred');
		},
	},
});
