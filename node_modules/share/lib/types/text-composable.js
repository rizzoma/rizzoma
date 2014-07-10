var checkOp, componentLength, i, invertComponent, makeAppend, makeTake, p, _base;

p = function() {};

i = function() {};

if (typeof exports === "undefined" || exports === null) exports = {};

exports.name = 'text-composable';

exports.create = function() {
  return '';
};

checkOp = function(op) {
  var c, last, _i, _len, _results;
  if (!Array.isArray(op)) throw new Error('Op must be an array of components');
  last = null;
  _results = [];
  for (_i = 0, _len = op.length; _i < _len; _i++) {
    c = op[_i];
    if (typeof c === 'object') {
      if (!(((c.i != null) && c.i.length > 0) || ((c.d != null) && c.d.length > 0))) {
        throw new Error("Invalid op component: " + (i(c)));
      }
    } else {
      if (typeof c !== 'number') {
        throw new Error('Op components must be objects or numbers');
      }
      if (!(c > 0)) throw new Error('Skip components must be a positive number');
      if (typeof last === 'number') {
        throw new Error('Adjacent skip components should be added');
      }
    }
    _results.push(last = c);
  }
  return _results;
};

exports._makeAppend = makeAppend = function(op) {
  return function(component) {
    if (component === 0 || component.i === '' || component.d === '') {} else if (op.length === 0) {
      return op.push(component);
    } else if (typeof component === 'number' && typeof op[op.length - 1] === 'number') {
      return op[op.length - 1] += component;
    } else if ((component.i != null) && (op[op.length - 1].i != null)) {
      return op[op.length - 1].i += component.i;
    } else if ((component.d != null) && (op[op.length - 1].d != null)) {
      return op[op.length - 1].d += component.d;
    } else {
      return op.push(component);
    }
  };
};

makeTake = function(op) {
  var idx, offset, peekType, take;
  idx = 0;
  offset = 0;
  take = function(n, indivisableField) {
    var c, field;
    if (idx === op.length) return null;
    if (typeof op[idx] === 'number') {
      if (!(n != null) || op[idx] - offset <= n) {
        c = op[idx] - offset;
        ++idx;
        offset = 0;
        return c;
      } else {
        offset += n;
        return n;
      }
    } else {
      field = op[idx].i ? 'i' : 'd';
      c = {};
      if (!(n != null) || op[idx][field].length - offset <= n || field === indivisableField) {
        c[field] = op[idx][field].slice(offset);
        ++idx;
        offset = 0;
      } else {
        c[field] = op[idx][field].slice(offset, (offset + n));
        offset += n;
      }
      return c;
    }
  };
  peekType = function() {
    return op[idx];
  };
  return [take, peekType];
};

componentLength = function(component) {
  if (typeof component === 'number') {
    return component;
  } else if (component.i != null) {
    return component.i.length;
  } else {
    return component.d.length;
  }
};

exports.normalize = function(op) {
  var append, component, newOp, _i, _len;
  newOp = [];
  append = makeAppend(newOp);
  for (_i = 0, _len = op.length; _i < _len; _i++) {
    component = op[_i];
    append(component);
  }
  return newOp;
};

exports.apply = function(str, op) {
  var component, newDoc, pos, _i, _len;
  p("Applying " + (i(op)) + " to '" + str + "'");
  if (typeof str !== 'string') throw new Error('Snapshot should be a string');
  checkOp(op);
  pos = 0;
  newDoc = [];
  for (_i = 0, _len = op.length; _i < _len; _i++) {
    component = op[_i];
    if (typeof component === 'number') {
      if (component > str.length) {
        throw new Error('The op is too long for this document');
      }
      newDoc.push(str.slice(0, component));
      str = str.slice(component);
    } else if (component.i != null) {
      newDoc.push(component.i);
    } else {
      if (component.d !== str.slice(0, component.d.length)) {
        throw new Error("The deleted text '" + component.d + "' doesn't match the next characters in the document '" + str.slice(0, component.d.length) + "'");
      }
      str = str.slice(component.d.length);
    }
  }
  if ('' !== str) {
    throw new Error("The applied op doesn't traverse the entire document");
  }
  return newDoc.join('');
};

exports.transform = function(op, otherOp, side) {
  var append, chunk, component, length, newOp, o, peek, take, _i, _len, _ref;
  if (!(side === 'left' || side === 'right')) {
    throw new Error("side (" + side + " must be 'left' or 'right'");
  }
  checkOp(op);
  checkOp(otherOp);
  newOp = [];
  append = makeAppend(newOp);
  _ref = makeTake(op), take = _ref[0], peek = _ref[1];
  for (_i = 0, _len = otherOp.length; _i < _len; _i++) {
    component = otherOp[_i];
    if (typeof component === 'number') {
      length = component;
      while (length > 0) {
        chunk = take(length, 'i');
        if (chunk === null) {
          throw new Error('The op traverses more elements than the document has');
        }
        append(chunk);
        if (!(typeof chunk === 'object' && (chunk.i != null))) {
          length -= componentLength(chunk);
        }
      }
    } else if (component.i != null) {
      if (side === 'left') {
        o = peek();
        if (o != null ? o.i : void 0) append(take());
      }
      append(component.i.length);
    } else {
      length = component.d.length;
      while (length > 0) {
        chunk = take(length, 'i');
        if (chunk === null) {
          throw new Error('The op traverses more elements than the document has');
        }
        if (typeof chunk === 'number') {
          length -= chunk;
        } else if (chunk.i != null) {
          append(chunk);
        } else {
          length -= chunk.d.length;
        }
      }
    }
  }
  while ((component = take())) {
    if ((component != null ? component.i : void 0) == null) {
      throw new Error("Remaining fragments in the op: " + (i(component)));
    }
    append(component);
  }
  return newOp;
};

exports.compose = function(op1, op2) {
  var append, chunk, component, length, offset, result, take, _, _i, _len, _ref;
  p("COMPOSE " + (i(op1)) + " + " + (i(op2)));
  checkOp(op1);
  checkOp(op2);
  result = [];
  append = makeAppend(result);
  _ref = makeTake(op1), take = _ref[0], _ = _ref[1];
  for (_i = 0, _len = op2.length; _i < _len; _i++) {
    component = op2[_i];
    if (typeof component === 'number') {
      length = component;
      while (length > 0) {
        chunk = take(length, 'd');
        if (chunk === null) {
          throw new Error('The op traverses more elements than the document has');
        }
        append(chunk);
        if (!(typeof chunk === 'object' && (chunk.d != null))) {
          length -= componentLength(chunk);
        }
      }
    } else if (component.i != null) {
      append({
        i: component.i
      });
    } else {
      offset = 0;
      while (offset < component.d.length) {
        chunk = take(component.d.length - offset, 'd');
        if (chunk === null) {
          throw new Error('The op traverses more elements than the document has');
        }
        if (typeof chunk === 'number') {
          append({
            d: component.d.slice(offset, (offset + chunk))
          });
          offset += chunk;
        } else if (chunk.i != null) {
          if (component.d.slice(offset, (offset + chunk.i.length)) !== chunk.i) {
            throw new Error("The deleted text doesn't match the inserted text");
          }
          offset += chunk.i.length;
        } else {
          append(chunk);
        }
      }
    }
  }
  while ((component = take())) {
    if ((component != null ? component.d : void 0) == null) {
      throw new Error("Trailing stuff in op1 " + (i(component)));
    }
    append(component);
  }
  return result;
};

invertComponent = function(c) {
  if (typeof c === 'number') {
    return c;
  } else if (c.i != null) {
    return {
      d: c.i
    };
  } else {
    return {
      i: c.d
    };
  }
};

exports.invert = function(op) {
  var append, component, result, _i, _len;
  result = [];
  append = makeAppend(result);
  for (_i = 0, _len = op.length; _i < _len; _i++) {
    component = op[_i];
    append(invertComponent(component));
  }
  return result;
};

if (typeof window !== "undefined" && window !== null) {
  window.ot || (window.ot = {});
  (_base = window.ot).types || (_base.types = {});
  window.ot.types.text = exports;
}
