async = require('async')
Conf = require('../../../conf').Conf
ProcessUtils = require('../../../utils/process_utils').ProcessUtils
{StateProcessor} = require('./state')

class FullIndexer

    constructor: () ->
        @_logger = Conf.getLogger('search')
        @_conf = Conf.getSearchIndexerConf() || {}
        @_indexCommand = @_conf.indexCommand
        @_mergeCommand = @_conf.mergeCommand
        @_stateFilePath = @_conf.stateFilePath
        @_sphinxConf = @_conf.fullIndexingSphinxConf or "./lib/etc/sphinxsearch/full-indexing.conf"

    run: (finish) ->
        async.whilst @_needRunNextIndexing, @_process, finish

    _needRunNextIndexing: (stat) =>
        state = StateProcessor.getState()
        console.log("Prev time processed #{state.processed}, startId: #{state.startId}")
        return state.processed != 0

    _process: (callback) =>
        ###
        индексируем, мерджим
        ###
        tasks = [
            (callback) =>
                @_index(callback)
            (callback) =>
                @_merge(callback)
        ]
        async.waterfall(tasks, callback)

    _index: (callback) =>
        ###
        Запускает индексацию.
        @param callback: function
        ###
        @_runCommand({INDEX_PREFIX: "full", SPHINX_CONF: @_sphinxConf}, @_indexCommand, [1], callback)

    _merge: (callback) =>
        ###
        Запускает слияние дельта-индекса с основным индексом.
        Слияние выполнится, если прошло больше _mergingThreshold с прошлого раза.
        @param lastMergingTime: number
        @param callback: function
        ###
        @_runCommand({INDEX_PREFIX: "full", SPHINX_CONF: @_sphinxConf}, @_mergeCommand, [0, 1], callback)

    _runCommand: (env, command, args=[], callback) ->
        ###
        Выполняет консольную команду (нужен для индексации и слияния).
        @param command: string
        @param callback: function
        ###
        listeners =
            out: (data) =>
                @_logger.debug(data.toString())
            err: (data) =>
                data = data.toString()
                func = if @_isError(data) then "error" else "debug"
                @_logger[func](data)
        ProcessUtils.spawn(command, args, env, listeners, callback)

    _isError: (data) ->
        ###
        Разбирает вывод stderr индексера - в него пишутся системные сообщения и
        сообщения об ошибках, в случае системного сообщения вернет false,
        @param data: string
        @return: bool
        @todo после обновления Coffee-script до 1.3.1 или выше проверить выдается ли предупреждение про path.existsSync, убрать из регулярного выражения
        ###
        return !data.match(/^(Starting process|Finished generation|path.existsSync is now called `fs.existsSync`.)/)


module.exports.FullIndexer = new FullIndexer()