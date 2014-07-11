_ = require('underscore')

class HashedQueue
    ###
    Класс, представляющий хэш очередей.
    ###
    constructor: (@_worker) ->
        ###
        @param _worker: function - функция, обрабатывающая одну задачу в очереди.
        После выполнения worker должен вызвать callback
            args..., callback
        ###
        @_queue = {}

    push: (key, args..., callback) ->
        ###
        Добавляет задачу в очередь.
        @param key: string - ключ по которому в очередь добавляется задача.
        @args - аргументы задачи
        @callback: function
        ###
        if key
            args.unshift(key)
        else
            key = 'single_key'
        @_queue[key] ||= {busy: false, tasks: []}
        @_queue[key].tasks.push({args: args, callback: callback})
        @_execute(key)

    _execute: (key) ->
        ###
        Обрабатывает следующую задачу в очереди.
        @param key: string
        ###
        process.nextTick(() =>
            item = @_queue[key]
            return if not item or item.busy
            item.busy = true
            task = item.tasks.shift()
            @_worker(task.args..., (args...) =>
                task.callback(args...)
                item.busy = false
                if not item.tasks.length
                    delete @_queue[key] 
                    return
                @_execute(key)
            )
        )

class HashedQueueWithCleansing extends HashedQueue
    ###
    Класс, представляющий хэш очередей с очисткой очереди.
    При каждом вызове _execute worker'у передастся все содержимое очереди
    после чего она очистится.
    ###
    constructor: (@_worker) ->
        super(@_worker)

    _execute: (key) ->
        ###
        Обрабатывает содержимое очереди.
        worker обязан сам вызвать callback'и для всех задач.
        @param key: string
        ###
        process.nextTick(() =>
            item = @_queue[key]
            return if not item or item.busy
            item.busy = true
            tasks = item.tasks
            item.tasks = []
            @_worker(tasks, () =>
                item.busy = false
                @_execute(key)
            )
        )

module.exports.HashedQueue = HashedQueue
module.exports.HashedQueueWithCleansing = HashedQueueWithCleansing
