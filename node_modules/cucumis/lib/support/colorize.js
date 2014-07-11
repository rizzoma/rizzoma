/**
 * Colorize the given string using ansi-escape sequences.
 * Disabled when --boring is set.
 *
 * @param {String} str
 * @return {String}
 */

module.exports.boring = false;

function colorize(color, str){
	var colors = { bold: 1, red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36 };
	if (arguments.length == 1) {
		str = color;
		return str.replace(/\[(\w+)\]\{([^]*?)\}/g, function(_, color, str){
			return module.exports.boring
				? str
				: '\x1B[' + colors[color] + 'm' + str + '\x1B[0m';
		});
	} else {
		return module.exports.boring
			? str
			: '\x1B[' + colors[color] + 'm' + str + '\x1B[0m';
	}
}

module.exports.colorize = colorize;
