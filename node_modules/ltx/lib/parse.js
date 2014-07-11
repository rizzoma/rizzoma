var events = require('events');
var util;
try {
    util = require('util');
} catch(e) {
    util = require('sys');
}
var expat = require('node-expat');
var element = require('./element');

exports.Parser = function() {
    var that = this;

    this.parser = new expat.Parser('UTF-8');

    var el;
    this.parser.addListener('startElement', function(name, attrs) {
        var child = new element.Element(name, attrs);
        if (!el) {
            el = child;
        } else {
            el = el.cnode(child);
        }
    });
    this.parser.addListener('endElement', function(name, attrs) {
        if (!el) {
            /* Err */
        } else if (el && name == el.name) {
            if (el.parent)
                el = el.parent;
            else if (!that.tree) {
                that.tree = el;
                el = undefined;
            }
        }
    });
    this.parser.addListener('text', function(str) {
        if (el)
            el.t(str);
    });
};
util.inherits(exports.Parser, events.EventEmitter);

exports.Parser.prototype.write = function(data) {
    if (!this.parser.parse(data, false)) {
        this.emit('error', new Error(this.parser.getError()));

        // Premature error thrown,
        // disable all functionality:
        this.write = function() { };
        this.end = function() { };
    }
};

exports.Parser.prototype.end = function() {
    if (!this.parser.parse('', true))
        this.emit('error', new Error(this.parser.getError()));
    else {
	if (this.tree)
	    this.emit('tree', this.tree);
	else
	    this.emit('error', new Error('Incomplete document'));
    }
};

exports.parse = function(data) {
    var p = new exports.Parser();
    var result = null, error = null;

    p.on('tree', function(tree) {
        result = tree;
    });
    p.on('error', function(e) {
        error = e;
    });

    p.write(data);
    p.end();

    if (error)
        throw error;
    else
        return result;
};
