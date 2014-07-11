async = require('async')
Conf = require('../conf').Conf
DbError = require('./db/exceptions').DbError

SEQUENCER_STRUCTURE =
    seq: 0

class SequenceGenerator
    ###
    Класс, представляющий генератор уникальных последовательностей.
    ###
    constructor: (@_sequencerId) ->
        @_db = Conf.getDb('main')
        conf = Conf.getGeneratorConf()
        @_sequencerHandler = conf.sequencerHandlerId
        @_awaitingRequests = []
        @_isBusy = true
        @_init()

    getNext: (offset, callback) ->
        ###
        Возвращает диапазон значений.
        @parms offset: int
        @param callback: function
        ###
        @_awaitingRequests.push({offset: offset, callback: callback})
        @_processAwaitingRequests()

    _init: () ->
        @_confirmSequencer()

    _confirmSequencer: () ->
        ###
        Проверяет наличие в БД документа, хранящего текущее максимальное значение.
        Если документа нет - создадим, инициализируя единицей.
        ###
        tasks = [
            (callback) =>
                @_db.get(@_sequencerId, (err, sequencer) ->
                    err = null if err and err.error == 'not_found'
                    callback(err, sequencer)
                )
            (hasSequencer, callback) =>
                return callback(null) if hasSequencer
                @_db.save(@_sequencerId, SEQUENCER_STRUCTURE, callback)
        ]
        async.waterfall(tasks, (err) =>
            throw new Error(err?.error or err?.message) if err
            @_isBusy = false
            @_processAwaitingRequests() if @_awaitingRequests.length
        )

    _processAwaitingRequests: () ->
        ###
        Обрабатывает запросы, пришедщие во время выполнения запроса к БД.
        ###
        return if @_isBusy
        @_isBusy = true
        awaitingRequests = @_awaitingRequests
        @_awaitingRequests = []
        totalOffset = @_getTotalOffset(awaitingRequests)
        @_executeRequest(totalOffset, (err, range) =>
            @_processCallbacks(awaitingRequests, err, range)
            @_isBusy = false
            @_processAwaitingRequests() if @_awaitingRequests.length
        )

    _getTotalOffset: (awaitingRequests) ->
        ###
        Получает суммарую длинну запрошенных диапозонов.
        @returns: int
        ###
        totalOffset = 0
        for request in awaitingRequests
            totalOffset += request.offset
        return totalOffset

    _processCallbacks: (awaitingRequests, err, range) ->
        return @_processCallbacksOnError(awaitingRequests, err) if err
        @_processCallbacksOnSuccess(awaitingRequests, range)

    _processCallbacksOnError: (awaitingRequests, err) ->
        ###
        Возвращает ошибку во callback'и всех запросов.
        ###
        for request in awaitingRequests
            request.callback(err, null)        

    _processCallbacksOnSuccess: (awaitingRequests, range) ->
        ###
        Возвращает диапазоны в каждый callback.
        ###
        start = range.start
        for request in awaitingRequests
            offset = start+request.offset
            request.callback(null, [start...offset])
            start = offset

    _executeRequest: (offset, callback) ->
        ###
        Выполняет запрос к базе.
        @param offset: int
        @param callback: function
        ###
        options = {offset: offset}
        @_db.update(@_sequencerHandler, @_sequencerId, options, (err, ids) =>
            return @_executeRequest(offset, callback) if err and err.error == 'conflict'
            callback(err, ids)
        )


class Generator
    ###
    Класс, представлющий id-генератор.
    ###
    constructor: () ->
        @_sequenceGenerator = new SequenceGenerator(@_sequencerId)
        if not @_sequencerId or not @_typePrefix
            throw new Error('Invalid properties definition')
        conf = Conf.getGeneratorConf()
        @_delimiter = conf.delimiter
        @_prefix = conf.prefix 
        @_base = conf.base

    getNext: (args..., callback) =>
        ###
        Возвращает один id.
        @param callback: function
        ###
        @_sequenceGenerator.getNext(1, (err, sourceIds) =>
            return callback(err, null) if err
            parts = @_getParts(args..., sourceIds[0])
            callback(null, @_makeId(parts))
        )
        
    getNextRange: (args..., offset, callback) =>
        ###
        Возвращает диапазон id.
        @param offset: int
        @param callback: function
        ###
        @_sequenceGenerator.getNext(offset, (err, sourceIds) => 
            return callback(err, null) if err
            ids = []
            for  sourceId in  sourceIds
                parts = @_getParts(args..., sourceId)
                ids.push(@_makeId(parts))
            callback(null, ids)
        )

    _getParts: (sourceId) ->
        ###
        Возвращает части из которых состоит id.
        @returns: array
        ###
        return [@_prefix, @_typePrefix, sourceId.toString(@_base)]

    _makeId: (parts) ->
        ###
        Возвращает id в ожидаемом клиентом формате.
        @param parts: array
        @returns: string
        ###
        return parts.join(@_delimiter)

module.exports = 
    SequenceGenerator: SequenceGenerator
    Generator: Generator
