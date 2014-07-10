_ = require('underscore')
Conf = require('../../conf').Conf
SphinxIndexer = require('./transport').SphinxIndexer
AmqpIndexer = require('./transport').AmqpIndexer

class Indexer
    ###
    Модуль, предоставляющий API для поиска. Обёртка над запуском индексации: отправкой задач в exchange либо локальной индексацией.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('search')
        options = Conf.getSearchIndexerConf() # Настройки для индексера
        indexerType = options.indexerType || "local"
        switch indexerType
            when "amqp"
                @_indexer = new AmqpIndexer()
            when "local"
                @_indexer = new SphinxIndexer()
            else
                throw new Error 'Unknown transport.'

    makeIndexSource: (callback) ->
        @_indexer.makeIndexSource()

module.exports.Indexer = new Indexer()