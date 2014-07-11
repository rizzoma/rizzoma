var SubDoc, depath, json, pathEquals, traverse,
  __slice = Array.prototype.slice;

if (typeof WEB === 'undefined') json = require('./json');

depath = function(path) {
  if (path.length === 1 && path[0].constructor === Array) {
    return path[0];
  } else {
    return path;
  }
};

SubDoc = (function() {

  function SubDoc(doc, path) {
    this.doc = doc;
    this.path = path;
  }

  SubDoc.prototype.at = function() {
    var path;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return this.doc.at(this.path.concat(depath(path)));
  };

  SubDoc.prototype.get = function() {
    return this.doc.getAt(this.path);
  };

  SubDoc.prototype.set = function(value, cb) {
    return this.doc.setAt(this.path, value, cb);
  };

  SubDoc.prototype.insert = function(pos, value, cb) {
    return this.doc.insertAt(this.path, pos, value, cb);
  };

  SubDoc.prototype.del = function(pos, length, cb) {
    return this.doc.deleteTextAt(this.path, length, pos, cb);
  };

  SubDoc.prototype.remove = function(cb) {
    return this.doc.removeAt(this.path, cb);
  };

  SubDoc.prototype.push = function(value, cb) {
    return this.insert(this.get().length, value, cb);
  };

  SubDoc.prototype.move = function(from, to, cb) {
    return this.doc.moveAt(this.path, from, to, cb);
  };

  SubDoc.prototype.add = function(amount, cb) {
    return this.doc.addAt(this.path, amount, cb);
  };

  SubDoc.prototype.on = function(event, cb) {
    return this.doc.addListener(this.path, event, cb);
  };

  SubDoc.prototype.removeListener = function(l) {
    return this.doc.removeListener(l);
  };

  SubDoc.prototype.getLength = function() {
    return this.get().length;
  };

  SubDoc.prototype.getText = function() {
    return this.get();
  };

  return SubDoc;

})();

traverse = function(snapshot, path) {
  var container, elem, key, p, _i, _len;
  container = {
    data: snapshot
  };
  key = 'data';
  elem = container;
  for (_i = 0, _len = path.length; _i < _len; _i++) {
    p = path[_i];
    elem = elem[key];
    key = p;
    if (typeof elem === 'undefined') throw new Error('bad path');
  }
  return {
    elem: elem,
    key: key
  };
};

pathEquals = function(p1, p2) {
  var e, i, _len;
  if (p1.length !== p2.length) return false;
  for (i = 0, _len = p1.length; i < _len; i++) {
    e = p1[i];
    if (e !== p2[i]) return false;
  }
  return true;
};

json.api = {
  provides: {
    json: true
  },
  at: function() {
    var path;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return new SubDoc(this, depath(path));
  },
  get: function() {
    return this.snapshot;
  },
  set: function(value, cb) {
    return this.setAt([], value, cb);
  },
  getAt: function(path) {
    var elem, key, _ref;
    _ref = traverse(this.snapshot, path), elem = _ref.elem, key = _ref.key;
    return elem[key];
  },
  setAt: function(path, value, cb) {
    var elem, key, op, _ref;
    _ref = traverse(this.snapshot, path), elem = _ref.elem, key = _ref.key;
    op = {
      p: path
    };
    if (elem.constructor === Array) {
      op.li = value;
      if (typeof elem[key] !== 'undefined') op.ld = elem[key];
    } else if (typeof elem === 'object') {
      op.oi = value;
      if (typeof elem[key] !== 'undefined') op.od = elem[key];
    } else {
      throw new Error('bad path');
    }
    return this.submitOp([op], cb);
  },
  removeAt: function(path, cb) {
    var elem, key, op, _ref;
    _ref = traverse(this.snapshot, path), elem = _ref.elem, key = _ref.key;
    if (typeof elem[key] === 'undefined') {
      throw new Error('no element at that path');
    }
    op = {
      p: path
    };
    if (elem.constructor === Array) {
      op.ld = elem[key];
    } else if (typeof elem === 'object') {
      op.od = elem[key];
    } else {
      throw new Error('bad path');
    }
    return this.submitOp([op], cb);
  },
  insertAt: function(path, pos, value, cb) {
    var elem, key, op, _ref;
    _ref = traverse(this.snapshot, path), elem = _ref.elem, key = _ref.key;
    op = {
      p: path.concat(pos)
    };
    if (elem[key].constructor === Array) {
      op.li = value;
    } else if (typeof elem[key] === 'string') {
      op.si = value;
    }
    return this.submitOp([op], cb);
  },
  moveAt: function(path, from, to, cb) {
    var op;
    op = [
      {
        p: path.concat(from),
        lm: to
      }
    ];
    return this.submitOp(op, cb);
  },
  addAt: function(path, amount, cb) {
    var op;
    op = [
      {
        p: path,
        na: amount
      }
    ];
    return this.submitOp(op, cb);
  },
  deleteTextAt: function(path, length, pos, cb) {
    var elem, key, op, _ref;
    _ref = traverse(this.snapshot, path), elem = _ref.elem, key = _ref.key;
    op = [
      {
        p: path.concat(pos),
        sd: elem[key].slice(pos, (pos + length))
      }
    ];
    return this.submitOp(op, cb);
  },
  addListener: function(path, event, cb) {
    var l;
    l = {
      path: path,
      event: event,
      cb: cb
    };
    this._listeners.push(l);
    return l;
  },
  removeListener: function(l) {
    var i;
    i = this._listeners.indexOf(l);
    if (i < 0) return false;
    this._listeners.splice(i, 1);
    return true;
  },
  _register: function() {
    this._listeners = [];
    this.on('change', function(op) {
      var c, dummy, i, l, to_remove, xformed, _i, _len, _len2, _ref, _results;
      _results = [];
      for (_i = 0, _len = op.length; _i < _len; _i++) {
        c = op[_i];
        if (c.na !== void 0 || c.si !== void 0 || c.sd !== void 0) continue;
        to_remove = [];
        _ref = this._listeners;
        for (i = 0, _len2 = _ref.length; i < _len2; i++) {
          l = _ref[i];
          dummy = {
            p: l.path,
            na: 0
          };
          xformed = this.type.transformComponent([], dummy, c, 'left');
          if (xformed.length === 0) {
            to_remove.push(i);
          } else if (xformed.length === 1) {
            l.path = xformed[0].p;
          } else {
            throw new Error("Bad assumption in json-api: xforming an 'si' op will always result in 0 or 1 components.");
          }
        }
        to_remove.sort(function(a, b) {
          return b - a;
        });
        _results.push((function() {
          var _j, _len3, _results2;
          _results2 = [];
          for (_j = 0, _len3 = to_remove.length; _j < _len3; _j++) {
            i = to_remove[_j];
            _results2.push(this._listeners.splice(i, 1));
          }
          return _results2;
        }).call(this));
      }
      return _results;
    });
    return this.on('remoteop', function(op) {
      var c, cb, child_path, common, event, match_path, path, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = op.length; _i < _len; _i++) {
        c = op[_i];
        match_path = c.na === void 0 ? c.p.slice(0, (c.p.length - 1)) : c.p;
        _results.push((function() {
          var _j, _len2, _ref, _ref2, _results2;
          _ref = this._listeners;
          _results2 = [];
          for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
            _ref2 = _ref[_j], path = _ref2.path, event = _ref2.event, cb = _ref2.cb;
            if (pathEquals(path, match_path)) {
              switch (event) {
                case 'insert':
                  if (c.li !== void 0 && c.ld === void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.li));
                  } else if (c.oi !== void 0 && c.od === void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.oi));
                  } else if (c.si !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.si));
                  } else {
                    _results2.push(void 0);
                  }
                  break;
                case 'delete':
                  if (c.li === void 0 && c.ld !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.ld));
                  } else if (c.oi === void 0 && c.od !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.od));
                  } else if (c.sd !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.sd));
                  } else {
                    _results2.push(void 0);
                  }
                  break;
                case 'replace':
                  if (c.li !== void 0 && c.ld !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.ld, c.li));
                  } else if (c.oi !== void 0 && c.od !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.od, c.oi));
                  } else {
                    _results2.push(void 0);
                  }
                  break;
                case 'move':
                  if (c.lm !== void 0) {
                    _results2.push(cb(c.p[c.p.length - 1], c.lm));
                  } else {
                    _results2.push(void 0);
                  }
                  break;
                case 'add':
                  if (c.na !== void 0) {
                    _results2.push(cb(c.na));
                  } else {
                    _results2.push(void 0);
                  }
                  break;
                default:
                  _results2.push(void 0);
              }
            } else if ((common = this.type.commonPath(match_path, path)) != null) {
              if (event === 'child op') {
                if (match_path.length === path.length) {
                  throw new Error("paths match length and have commonality, but aren't equal?");
                }
                child_path = c.p.slice(common + 1);
                _results2.push(cb(child_path, c));
              } else {
                _results2.push(void 0);
              }
            } else {
              _results2.push(void 0);
            }
          }
          return _results2;
        }).call(this));
      }
      return _results;
    });
  }
};
