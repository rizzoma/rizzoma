var append, appendSkipChars, takeDoc, type;

if (typeof WEB !== "undefined" && WEB !== null) {
  type = exports.types['text-tp2'];
} else {
  type = require('./text-tp2');
}

takeDoc = type._takeDoc, append = type._append;

appendSkipChars = function(op, doc, pos, maxlength) {
  var part, _results;
  _results = [];
  while ((maxlength === void 0 || maxlength > 0) && pos.index < doc.data.length) {
    part = takeDoc(doc, pos, maxlength, true);
    if (maxlength !== void 0 && typeof part === 'string') maxlength -= part.length;
    _results.push(append(op, part.length || part));
  }
  return _results;
};

type['api'] = {
  'provides': {
    'text': true
  },
  'getLength': function() {
    return this.snapshot.charLength;
  },
  'getText': function() {
    var elem, strings;
    strings = (function() {
      var _i, _len, _ref, _results;
      _ref = this.snapshot.data;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        elem = _ref[_i];
        if (typeof elem === 'string') _results.push(elem);
      }
      return _results;
    }).call(this);
    return strings.join('');
  },
  'insert': function(pos, text, callback) {
    var docPos, op;
    if (pos === void 0) pos = 0;
    op = [];
    docPos = {
      index: 0,
      offset: 0
    };
    appendSkipChars(op, this.snapshot, docPos, pos);
    append(op, {
      'i': text
    });
    appendSkipChars(op, this.snapshot, docPos);
    this.submitOp(op, callback);
    return op;
  },
  'del': function(pos, length, callback) {
    var docPos, op, part;
    op = [];
    docPos = {
      index: 0,
      offset: 0
    };
    appendSkipChars(op, this.snapshot, docPos, pos);
    while (length > 0) {
      part = takeDoc(this.snapshot, docPos, length, true);
      if (typeof part === 'string') {
        append(op, {
          'd': part.length
        });
        length -= part.length;
      } else {
        append(op, part);
      }
    }
    appendSkipChars(op, this.snapshot, docPos);
    this.submitOp(op, callback);
    return op;
  },
  '_register': function() {
    return this.on('remoteop', function(op, snapshot) {
      var component, docPos, part, remainder, textPos, _i, _len;
      textPos = 0;
      docPos = {
        index: 0,
        offset: 0
      };
      for (_i = 0, _len = op.length; _i < _len; _i++) {
        component = op[_i];
        if (typeof component === 'number') {
          remainder = component;
          while (remainder > 0) {
            part = takeDoc(snapshot, docPos, remainder);
            if (typeof part === 'string') textPos += part.length;
            remainder -= part.length || part;
          }
        } else if (component.i !== void 0) {
          if (typeof component.i === 'string') {
            this.emit('insert', textPos, component.i);
            textPos += component.i.length;
          }
        } else {
          remainder = component.d;
          while (remainder > 0) {
            part = takeDoc(snapshot, docPos, remainder);
            if (typeof part === 'string') this.emit('delete', textPos, part);
            remainder -= part.length || part;
          }
        }
      }
    });
  }
};
