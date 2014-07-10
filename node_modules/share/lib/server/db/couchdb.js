var parseError, request;

request = require('request').defaults({
  json: true
});

parseError = function(err, resp, body, callback) {
  if (Array.isArray(body && body.length >= 1)) body = body[0];
  if (err) {
    return callback(err);
  } else if (resp.statusCode === 404) {
    return callback('Document does not exist');
  } else if (resp.statusCode === 403) {
    return callback('forbidden');
  } else if (typeof body === 'object') {
    if (body.error === 'conflict') {
      return callback('Document already exists');
    } else if (body.error) {
      return callback("" + body.error + " reason: " + body.reason);
    } else {
      return callback();
    }
  } else {
    return callback();
  }
};

module.exports = function(options) {
  var db, del, getRev, uriForDoc, uriForOps, writeSnapshotInternal;
  if (options == null) options = {};
  db = options.uri || "http://localhost:5984/sharejs";
  uriForDoc = function(docName) {
    return "" + db + "/doc:" + (encodeURIComponent(docName));
  };
  uriForOps = function(docName, start, end, include_docs) {
    var endkey, extra, startkey;
    startkey = encodeURIComponent(JSON.stringify([docName, start]));
    endkey = encodeURIComponent(JSON.stringify([docName, end != null ? end : {}]));
    extra = include_docs ? '&include_docs=true' : '';
    return "" + db + "/_design/sharejs/_view/operations?startkey=" + startkey + "&endkey=" + endkey + "&inclusive_end=false" + extra;
  };
  getRev = function(docName, dbMeta, callback) {
    if (dbMeta != null ? dbMeta.rev : void 0) {
      return callback(null, dbMeta.rev);
    } else {
      return request.head({
        uri: uriForDoc(docName),
        json: false
      }, function(err, resp, body) {
        return parseError(err, resp, body, function(error) {
          if (error) {
            return callback(error);
          } else {
            return callback(null, JSON.parse(resp.headers.etag));
          }
        });
      });
    }
  };
  writeSnapshotInternal = function(docName, data, rev, callback) {
    var body;
    body = data;
    body.fieldType = 'Document';
    if (rev != null) body._rev = rev;
    return request.put({
      uri: uriForDoc(docName),
      body: body
    }, function(err, resp, body) {
      return parseError(err, resp, body, function(error) {
        if (error) {
          return typeof callback === "function" ? callback(error) : void 0;
        } else {
          return typeof callback === "function" ? callback(null, {
            rev: body.rev
          }) : void 0;
        }
      });
    });
  };
  return {
    getOps: function(docName, start, end, callback) {
      var endkey;
      if (start === end) return callback(null, []);
      endkey = end != null ? [docName, end - 1] : void 0;
      return request(uriForOps(docName, start, end), function(err, resp, body) {
        var data, row;
        data = (function() {
          var _i, _len, _ref, _results;
          _ref = body.rows;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            row = _ref[_i];
            _results.push({
              op: row.value.op,
              meta: row.value.meta
            });
          }
          return _results;
        })();
        return callback(null, data);
      });
    },
    create: function(docName, data, callback) {
      return writeSnapshotInternal(docName, data, null, callback);
    },
    "delete": del = function(docName, dbMeta, callback) {
      return getRev(docName, dbMeta, function(error, rev) {
        var docs;
        if (error) {
          return typeof callback === "function" ? callback(error) : void 0;
        }
        docs = [
          {
            _id: "doc:" + docName,
            _rev: rev,
            _deleted: true
          }
        ];
        return request(uriForOps(docName, 0, null, true), function(err, resp, body) {
          var row, _i, _len, _ref;
          _ref = body.rows;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            row = _ref[_i];
            row.doc._deleted = true;
            docs.push(row.doc);
          }
          return request.post({
            url: "" + db + "/_bulk_docs",
            body: {
              docs: docs
            }
          }, function(err, resp, body) {
            if (body[0].error === 'conflict') {
              return del(docName, null, callback);
            } else {
              return parseError(err, resp, body, function(error) {
                return typeof callback === "function" ? callback(error) : void 0;
              });
            }
          });
        });
      });
    },
    writeOp: function(docName, opData, callback) {
      var body;
      body = {
        docName: docName,
        op: opData.op,
        v: opData.v,
        meta: opData.meta
      };
      return request.post({
        url: db,
        body: body
      }, function(err, resp, body) {
        return parseError(err, resp, body, callback);
      });
    },
    writeSnapshot: function(docName, docData, dbMeta, callback) {
      return getRev(docName, dbMeta, function(error, rev) {
        if (error) {
          return typeof callback === "function" ? callback(error) : void 0;
        }
        return writeSnapshotInternal(docName, docData, rev, callback);
      });
    },
    getSnapshot: function(docName, callback) {
      return request(uriForDoc(docName), function(err, resp, body) {
        return parseError(err, resp, body, function(error) {
          if (error) {
            return callback(error);
          } else {
            return callback(null, {
              snapshot: body.snapshot,
              type: body.type,
              meta: body.meta,
              v: body.v
            }, {
              rev: body._rev
            });
          }
        });
      });
    },
    close: function() {}
  };
};
