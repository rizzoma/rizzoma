_ = require('underscore')
Model = require('../common/model').Model
OPERATION_TYPE = require('./constants').OPERATION_TYPE
generatorConf= require('../conf').Conf.getGeneratorConf()
generatorConf= require('../conf').Conf.getGeneratorConf()

delimiter = generatorConf['delimiter']
prefix = generatorConf['prefix']

class OperationModel extends Model
    ###
    Класс представляющий модель операции.
    ###
    constructor: (sourceId=null, @docId=null, @version=0, @op=null, @user='server', @timestamp=null, @listenerId=null, @_rev=undefined) ->
        @_sourceId = if _.isArray(sourceId) then sourceId.join(delimiter) else sourceId
        @_random = Math.random()
        @setId()
        super('operation')

    setRandom: (random) ->
        @_random = random if random

    getRandom: () ->
        ###
        Random just unique string, we shuldn't compare ramdoms as float values
        ###
        return "#{@_random}"

    setId: () ->
        ###
        Выставляет id модели. Нужен для того, что бы скорректировать id относительно версии.
        ###
        @id = [prefix, OPERATION_TYPE, @_sourceId, @version].join(delimiter)
            

module.exports.OperationModel = OperationModel
