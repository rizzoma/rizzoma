var Connection, Doc, MicroEvent, io, types,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

if (typeof WEB !== "undefined" && WEB !== null) {
  types || (types = exports.types);
  if (!window.io) throw new Error('Must load socket.io before this library');
  io = window.io;
} else {
  types = require('../types');
  io = require('socket.io-client');
  Doc = require('./doc').Doc;
}

Connection = (function() {

  function Connection(origin) {
    this.onMessage = __bind(this.onMessage, this);
    this.connected = __bind(this.connected, this);
    this.disconnected = __bind(this.disconnected, this);
    var _this = this;
    this.docs = {};
    this.handlers = {};
    this.state = 'connecting';
    this.socket = io.connect(origin, {
      'force new connection': true
    });
    this.socket.on('connect', this.connected);
    this.socket.on('disconnect', this.disconnected);
    this.socket.on('message', this.onMessage);
    this.socket.on('connect_failed', function(error) {
      var callback, callbacks, docName, h, t, _ref, _results;
      if (error === 'unauthorized') error = 'forbidden';
      _this.socket = null;
      _this.emit('connect failed', error);
      _ref = _this.handlers;
      _results = [];
      for (docName in _ref) {
        h = _ref[docName];
        _results.push((function() {
          var _results2;
          _results2 = [];
          for (t in h) {
            callbacks = h[t];
            _results2.push((function() {
              var _i, _len, _results3;
              _results3 = [];
              for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
                callback = callbacks[_i];
                _results3.push(callback(error));
              }
              return _results3;
            })());
          }
          return _results2;
        })());
      }
      return _results;
    });
  }

  Connection.prototype.disconnected = function() {
    this.emit('disconnect');
    return this.socket = null;
  };

  Connection.prototype.connected = function() {
    return this.emit('connect');
  };

  Connection.prototype.send = function(msg, callback) {
    var callbacks, docHandlers, docName, type, _base;
    if (this.socket === null) {
      throw new Error("Cannot send message " + (JSON.stringify(msg)) + " to a closed connection");
    }
    docName = msg.doc;
    if (docName === this.lastSentDoc) {
      delete msg.doc;
    } else {
      this.lastSentDoc = docName;
    }
    this.socket.json.send(msg);
    if (callback) {
      type = msg.open === true ? 'open' : msg.open === false ? 'close' : msg.create ? 'create' : msg.snapshot === null ? 'snapshot' : msg.op ? 'op response' : void 0;
      docHandlers = ((_base = this.handlers)[docName] || (_base[docName] = {}));
      callbacks = (docHandlers[type] || (docHandlers[type] = []));
      return callbacks.push(callback);
    }
  };

  Connection.prototype.onMessage = function(msg) {
    var c, callbacks, doc, docName, type, _i, _len, _ref;
    docName = msg.doc;
    if (docName !== void 0) {
      this.lastReceivedDoc = docName;
    } else {
      msg.doc = docName = this.lastReceivedDoc;
    }
    this.emit('message', msg);
    type = msg.open === true || (msg.open === false && msg.error) ? 'open' : msg.open === false ? 'close' : msg.snapshot !== void 0 ? 'snapshot' : msg.create ? 'create' : msg.op ? 'op' : msg.v !== void 0 ? 'op response' : void 0;
    callbacks = (_ref = this.handlers[docName]) != null ? _ref[type] : void 0;
    if (callbacks) {
      delete this.handlers[docName][type];
      for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
        c = callbacks[_i];
        c(msg.error, msg);
      }
    }
    if (type === 'op') {
      doc = this.docs[docName];
      if (doc) return doc._onOpReceived(msg);
    }
  };

  Connection.prototype.makeDoc = function(params) {
    var doc, name, type,
      _this = this;
    name = params.doc;
    if (this.docs[name]) throw new Error("Doc " + name + " already open");
    type = params.type;
    if (typeof type === 'string') type = types[type];
    doc = new Doc(this, name, params.v, type, params.snapshot);
    doc.created = !!params.create;
    this.docs[name] = doc;
    doc.on('closing', function() {
      return delete _this.docs[name];
    });
    return doc;
  };

  Connection.prototype.openExisting = function(docName, callback) {
    var _this = this;
    if (this.socket === null) {
      callback('connection closed');
      return;
    }
    if (this.docs[docName] != null) return this.docs[docName];
    return this.send({
      'doc': docName,
      'open': true,
      'snapshot': null
    }, function(error, response) {
      if (error) {
        return callback(error);
      } else {
        return callback(null, _this.makeDoc(response));
      }
    });
  };

  Connection.prototype.open = function(docName, type, callback) {
    var doc,
      _this = this;
    if (this.socket === null) {
      callback('connection closed');
      return;
    }
    if (typeof type === 'function') {
      callback = type;
      type = 'text';
    }
    callback || (callback = function() {});
    if (typeof type === 'string') type = types[type];
    if (!type) throw new Error("OT code for document type missing");
    if ((docName != null) && (this.docs[docName] != null)) {
      doc = this.docs[docName];
      if (doc.type === type) {
        callback(null, doc);
      } else {
        callback('Type mismatch', doc);
      }
      return;
    }
    return this.send({
      'doc': docName,
      'open': true,
      'create': true,
      'snapshot': null,
      'type': type.name
    }, function(error, response) {
      if (error) {
        return callback(error);
      } else {
        if (response.snapshot === void 0) response.snapshot = type.create();
        response.type = type;
        return callback(null, _this.makeDoc(response));
      }
    });
  };

  Connection.prototype.create = function(type, callback) {
    return open(null, type, callback);
  };

  Connection.prototype.disconnect = function() {
    if (this.socket) {
      this.emit('disconnecting');
      this.socket.disconnect();
      return this.socket = null;
    }
  };

  return Connection;

})();

if (typeof WEB === "undefined" || WEB === null) {
  MicroEvent = require('./microevent');
}

MicroEvent.mixin(Connection);

exports.Connection = Connection;
