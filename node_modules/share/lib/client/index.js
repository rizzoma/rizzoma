var Connection;

if (typeof WEB === "undefined" || WEB === null) {
  Connection = require('./connection').Connection;
}

exports.open = (function() {
  var connections, getConnection;
  connections = {};
  getConnection = function(origin) {
    var c, del, location;
    if (typeof WEB !== "undefined" && WEB !== null) {
      location = window.location;
      if (origin == null) {
        origin = "" + location.protocol + "//" + location.hostname + "/sjs";
      }
    }
    if (!connections[origin]) {
      c = new Connection(origin);
      c.numDocs = 0;
      del = function() {
        return delete connections[origin];
      };
      c.on('disconnecting', del);
      c.on('connect failed', del);
      connections[origin] = c;
    }
    return connections[origin];
  };
  return function(docName, type, origin, callback) {
    var c;
    if (typeof origin === 'function') {
      callback = origin;
      origin = null;
    }
    c = getConnection(origin);
    c.numDocs++;
    c.open(docName, type, function(error, doc) {
      if (error) {
        c.numDocs--;
        if (c.numDocs === 0) c.disconnect();
        return callback(error);
      } else {
        doc.on('closed', function() {
          c.numDocs--;
          if (c.numDocs === 0) return c.disconnect();
        });
        return callback(null, doc);
      }
    });
    return c.on('connect failed');
  };
})();

if (typeof WEB === "undefined" || WEB === null) {
  exports.Doc = require('./doc').Doc;
  exports.Connection = require('./connection').Connection;
}
