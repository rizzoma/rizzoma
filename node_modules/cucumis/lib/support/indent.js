var _ = require('underscore');

function indent (text, level) {
	level = level || 0;

	var lines = text.split('\n');

	var indents = '';
	_.range(level).forEach(function() {
		indents += '  ';
	});

	for (var i = 0; i < lines.length; i++) {
		lines[i] = indents + lines[i]; 
	}

	return lines.join('\n');
}

module.exports = indent;
