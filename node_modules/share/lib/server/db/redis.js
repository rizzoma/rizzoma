var RedisDb, defaultOptions, redis;

redis = require('redis');

defaultOptions = {
  prefix: 'ShareJS:',
  hostname: null,
  port: null,
  redisOptions: null,
  testing: false
};

module.exports = RedisDb = function(options) {
  var client, k, keyForDoc, keyForOps, v;
  if (!(this instanceof RedisDb)) return new Db;
  if (options == null) options = {};
  for (k in defaultOptions) {
    v = defaultOptions[k];
    if (options[k] == null) options[k] = v;
  }
  keyForOps = function(docName) {
    return "" + options.prefix + "ops:" + docName;
  };
  keyForDoc = function(docName) {
    return "" + options.prefix + "doc:" + docName;
  };
  client = redis.createClient(options.port, options.hostname, options.redisOptions);
  if (options.testing) client.select(15);
  this.create = function(docName, data, callback) {
    var value;
    value = JSON.stringify(data);
    return client.setnx(keyForDoc(docName), value, function(err, result) {
      if (err) return typeof callback === "function" ? callback(err) : void 0;
      if (result) {
        return typeof callback === "function" ? callback() : void 0;
      } else {
        return typeof callback === "function" ? callback('Document already exists') : void 0;
      }
    });
  };
  this.getOps = function(docName, start, end, callback) {
    if (start === end) {
      callback(null, []);
      return;
    }
    if (end != null) {
      end--;
    } else {
      end = -1;
    }
    return client.lrange(keyForOps(docName), start, end, function(err, values) {
      var ops, value;
      if (err != null) throw err;
      ops = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = values.length; _i < _len; _i++) {
          value = values[_i];
          _results.push(JSON.parse(value));
        }
        return _results;
      })();
      return callback(null, ops);
    });
  };
  this.writeOp = function(docName, opData, callback) {
    var json;
    json = JSON.stringify({
      op: opData.op,
      meta: opData.meta
    });
    return client.rpush(keyForOps(docName), json, function(err, response) {
      if (err) return callback(err);
      if (response === opData.v + 1) {
        return callback();
      } else {
        return callback("Version mismatch in db.append. '" + docName + "' is corrupted.");
      }
    });
  };
  this.writeSnapshot = function(docName, docData, dbMeta, callback) {
    return client.set(keyForDoc(docName), JSON.stringify(docData), function(err, response) {
      return typeof callback === "function" ? callback(err) : void 0;
    });
  };
  this.getSnapshot = function(docName, callback) {
    return client.get(keyForDoc(docName), function(err, response) {
      var docData;
      if (err != null) throw err;
      if (response !== null) {
        docData = JSON.parse(response);
        return callback(null, docData);
      } else {
        return callback('Document does not exist');
      }
    });
  };
  this["delete"] = function(docName, dbMeta, callback) {
    client.del(keyForOps(docName));
    return client.del(keyForDoc(docName), function(err, response) {
      if (err != null) throw err;
      if (callback) {
        if (response === 1) {
          return callback(null);
        } else {
          return callback('Document does not exist');
        }
      }
    });
  };
  this.close = function() {
    return client.quit();
  };
  return this;
};
