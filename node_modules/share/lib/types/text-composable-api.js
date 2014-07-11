var type;

if (typeof WEB !== "undefined" && WEB !== null) {
  type = exports.types['text-composable'];
} else {
  type = require('./text-composable');
}

type.api = {
  provides: {
    'text': true
  },
  'getLength': function() {
    return this.snapshot.length;
  },
  'getText': function() {
    return this.snapshot;
  },
  'insert': function(pos, text, callback) {
    var op;
    op = type.normalize([
      pos, {
        'i': text
      }, this.snapshot.length - pos
    ]);
    this.submitOp(op, callback);
    return op;
  },
  'del': function(pos, length, callback) {
    var op;
    op = type.normalize([
      pos, {
        'd': this.snapshot.slice(pos, (pos + length))
      }, this.snapshot.length - pos - length
    ]);
    this.submitOp(op, callback);
    return op;
  },
  _register: function() {
    return this.on('remoteop', function(op) {
      var component, pos, _i, _len, _results;
      pos = 0;
      _results = [];
      for (_i = 0, _len = op.length; _i < _len; _i++) {
        component = op[_i];
        if (typeof component === 'number') {
          _results.push(pos += component);
        } else if (component.i !== void 0) {
          this.emit('insert', pos, component.i);
          _results.push(pos += component.i.length);
        } else {
          _results.push(this.emit('delete', pos, component.d));
        }
      }
      return _results;
    });
  }
};
