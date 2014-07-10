module.exports = require('kyuri');

var events = require('events'),
    util = require('util');

function Runner() {
	events.EventEmitter.call(this);
}

util.inherits(Runner, events.EventEmitter);

module.exports.Steps.Runner = new Runner();
