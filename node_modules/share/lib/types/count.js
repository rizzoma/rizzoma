
exports.name = 'count';

exports.create = function() {
  return 1;
};

exports.apply = function(snapshot, op) {
  var inc, v;
  v = op[0], inc = op[1];
  if (snapshot !== v) throw new Error("Op " + v + " != snapshot " + snapshot);
  return snapshot + inc;
};

exports.transform = function(op1, op2) {
  if (op1[0] !== op2[0]) throw new Error("Op1 " + op1[0] + " != op2 " + op2[0]);
  return [op1[0] + op2[1], op1[1]];
};

exports.compose = function(op1, op2) {
  if (op1[0] + op1[1] !== op2[0]) {
    throw new Error("Op1 " + op1 + " + 1 != op2 " + op2);
  }
  return [op1[0], op1[1] + op2[1]];
};

exports.generateRandomOp = function(doc) {
  return [[doc, 1], doc + 1];
};
