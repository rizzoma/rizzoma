UserModel = require('./model').UserModel
ANONYMOUS_ID = require('./constants').ANONYMOUS_ID

module.exports = new UserModel(ANONYMOUS_ID)