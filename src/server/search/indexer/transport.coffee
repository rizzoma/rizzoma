fs = require('fs')
_ = require('underscore')
async = require('async')
child_process = require('child_process')
Conf = require('../../conf').Conf
CouchSearchProcessor = require('../couch_processor').CouchSearchProcessor
DateUtils = require('../../utils/date_utils').DateUtils
AmqpAdapter = require('../../common/amqp').AmqpAdapter
ProcessUtils = require('../../utils/process_utils').ProcessUtils
MergeStateProcessor = require('./state').MergeStateProcessor
BackupStateProcessor = require('./state').BackupStateProcessor


class BaseIndexer
    ###
    Базовый класс для индексации поисковых процессоров.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('search')
        @_conf = Conf.getSearchIndexerConf() || {}

    makeIndexSource: (callback) ->
        callback(new Error("Method is not emplemented"), null)


class SphinxIndexer extends BaseIndexer
    ###
    Локальный запуск индексации из самого процесса.
    ###
    constructor: () ->
        ###
        Инициализирует индексатор
        ###
        super()
        @_indexes = @_conf.indexes || []
        @_indexCommand = @_conf.indexCommand
        @_mergeCommand = @_conf.mergeCommand
        @_backupCommand = @_conf.backup.command if @_conf.backup
        # состояния индекса в данный момент свободен/занят
        @_lastIndexingDuration = 0
        @_busy = {}
        @_tasks = @_initTasks()
        @_fromTask = @_tasks.length

    _initTasks: () ->
        ###
        Иницируем задачи которые будут выполнятся над индексами
        interface Task
            isBusy: () ->
            fn: () ->
        ###
        # если нет индексов то и не индексируем
        return [] if not @_indexes or not @_indexes.length
        indexing =
            isBusy: () => return @_busy[@_indexes.length-1]
            fn: async.apply(@_index, @_indexes.length-1)
        tasks = [ indexing ]
        # если индексов больше одного то добавляем мерджинг
        if @_indexes.length > 1
            for i in [@_indexes.length-1..1]
                merging =
                    isBusy: do(i) =>
                        return () => return @_busy[i] or @_busy[i-1]
                    fn: async.apply(@_merge, i, i-1)
                tasks.push(merging)
        # ну и забэкапим 0 индекс
        if @_conf.backup
            backuping =
                isBusy: () => return @_busy[0]
                fn: async.apply(@_backup, 0)
            tasks.push(backuping)
        return tasks

    makeIndexSource: (callback) ->
        ###
        Выбирает из базы все недавно измененные блипы и инициирует их запись в исходник.
        Одновременно обрабатывается только 1 запрос, остальные откладываются и будут обработаны позже.
        Перед индексацией метод спит в течении _indexingThreshold
        @param request: Request
        ###
        callback?(null, true)
        @_process(0)

    _process: (fromTask) ->
        @_processTasks(fromTask, (err, fromTask) =>
            return @_logger.error(err) if err
            # если чего то занято проставляем с какого места начать и выходим
            if fromTask < @_tasks.length
                @_fromTask = fromTask if fromTask < @_fromTask
                return
            if @_fromTask < @_tasks.length
                fromTask = @_fromTask
                @_fromTask = @_tasks.length
                @_process(fromTask)
        )

    _processTasks: (fromTask, callback) ->
        ###
        Выполняет индексацию и слияние индексов, а также если нужно запускает бэкап
        @param fromTask: int
        returns: int - индекс задачи на которой прервали выполнение
        ###
        tasks = []
        for i in [fromTask..@_tasks.length-1]
            t = @_tasks[i]
            break if t.isBusy()
            tasks.push(t.fn)
        async.series(tasks, (err, res) =>
            return callback(err, null) if err
            callback(null, res.length)
        )

    _isError: (data) ->
        ###
        Разбирает вывод stderr индексера - в него пишутся системные сообщения и
        сообщения об ошибках, в случае системного сообщения вернет false,
        @param data: string
        @return: bool
        @todo после обновления Coffee-script до 1.3.1 или выше проверить выдается ли предупреждение про path.existsSync, убрать из регулярного выражения
        ###
        return !data.match(/^(Starting process|Finished generation|path.existsSync is now called `fs.existsSync`.)/)

    _runCommand: (command, args=[], callback) ->
        ###
        Выполняет консольную команду (нужен для индексации и слияния).
        @param command: string
        @param callback: function
        ###
        env = {INDEX_PREFIX: @_conf.indexPrefix}
        listeners =
            out: (data) =>
                @_logger.debug(data.toString())
            err: (data) =>
                data = data.toString()
                func = if @_isError(data) then "error" else "debug"
                @_logger[func](data)
        ProcessUtils.spawn(command, args, env, listeners, callback)

    _index: (index, callback) =>
        ###
        Запускает индексацию.
        @param callback: function
        ###
        conf = @_indexes[index]
        @_busy[index] = true
        setTimeout(() =>
            started = DateUtils.getCurrentTimestamp()
            @_runCommand(@_indexCommand, [index], (err) =>
                if err
                    @_busy[index] = false
                    return callback(err)
                @_busy[index] = false
                @_lastIndexingDuration = DateUtils.getCurrentTimestamp() - started
                callback(null)
            )
        , conf.threshold * 1000)

    _merge: (fromIndex, toIndex, callback) =>
        ###
        Запускает слияние дельта-индекса с основным индексом.
        Слияние выполнится, если прошло больше _mergingThreshold с прошлого раза.
        @param lastMergingTime: number
        @param callback: function
        ###
        conf = @_indexes[toIndex]
        try
            lastMergingTime = MergeStateProcessor.getTimestamp(toIndex)
        catch err
            return callback(err)
        # важно: запоминаем время до начала мерджа чтобы не пропустить измененные за это время блипы
        now = DateUtils.getCurrentTimestamp()
        return callback(null) if now - lastMergingTime < conf.threshold
        nowHour = new Date().getHours()
        if conf.between and conf.between.length == 2 and (nowHour < conf.between[0] or nowHour >= conf.between[1])
            return callback(null)
        @_busy[fromIndex] = true
        @_busy[toIndex] = true
        @_runCommand(@_mergeCommand, [toIndex, fromIndex], (err) =>
            if err
                @_busy[fromIndex] = false
                @_busy[toIndex] = false
                return callback(err)
            try
                # важно: если перед мерджем выполнялась индексация вычтем время и на нее чтобы не пропустить измененые блипы
                # это время отнимется также и при мердже 1 -> 0 но оно будет мало, поэтому пофиг
                # ну и 5 сек вообще на всякий случай
                mergeTimestamp = now - @_lastIndexingDuration - 5
                MergeStateProcessor.updateTimestamp(toIndex, mergeTimestamp)
            catch err
                @_busy[fromIndex] = false
                @_busy[toIndex] = false
                return callback(err)
            @_busy[fromIndex] = false
            @_busy[toIndex] = false
            callback(null)
        )

    _backup: (index, callback) =>
        lastBackupTime = BackupStateProcessor.getTimestamp(index)
        conf = @_conf.backup
        now = DateUtils.getCurrentTimestamp()
        return callback(null) if now - lastBackupTime < conf.threshold
        nowHour = new Date().getHours()
        if conf.between and conf.between.length == 2 and (nowHour < conf.between[0] or nowHour >= conf.between[1])
            return callback(null)
        @_busy[index] = true
        @_runCommand(conf.command, null, (err) =>
            if err
                @_busy[index] = false
                return callback(err)
            try
                BackupStateProcessor.updateTimestamp(index)
            catch err
                @_busy[index] = false
                return callback(err)
            @_busy[index] = false
            callback(null)
        )

class AmqpIndexer extends BaseIndexer
    ###
    Запрос через AMQP на создание индексов.
    ###
    constructor: () ->
        super()
        @_hasUnSent = false # Есть ли неотправленные данные
        amqpAdapterOptions = Conf.getAmqpConf() || {}
        amqpOptions = @_conf.amqpOptions || {}
        @_queriesRoutingKey = amqpOptions.queriesRoutingKey || "indexer"
        _.extend(amqpAdapterOptions, amqpOptions)
        @_connected = false
        @_amqp = new AmqpAdapter(amqpAdapterOptions)
        @_amqp.on 'close', () =>
            @_connected = false
        @_amqp.on 'exchange-ready', () =>
            if @_hasUnSent
                @_sendNotification()
            @_connected = true
        @_amqp.connect((err) =>
            if err
                return @_logger.error(err)
        )

    _sendNotification: () ->
        ###
        Отправка уведомления "сделай переиндексацию".
        ###
        @_amqp.publish(@_queriesRoutingKey, 'makeIndexer') # Отправляем уведомления
        @_hasUnSent = false

    makeIndexSource: (callback) ->
        if @_connected
            @_sendNotification()
        else
            @_hasUnSent = true # Появилось неотправленное сообщение
        callback?(null, true)


module.exports =
    SphinxIndexer: SphinxIndexer
    AmqpIndexer: AmqpIndexer
