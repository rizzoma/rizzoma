###
Создает очередь команд для последовательного выполнения (для использования с Cakefile и пр.).
Умеет выполнять shell-команды и асинхронные js-функции, с передачей им аргументов.
Команды в очередь добавляются методом cmd:
- cmd("pwd", callback)
- cmd(func, callback)
- cmd("mkdir", ["-p", "1"], callback) # TODO сейчас прием аргументов не реализован
- cmd(fs.mkdir, ["1", 0755], callback)
###
{exec} = require 'child_process'
sys = require 'util'
async = require 'async'
require 'colors' # colorize terminal output

# Вспомогательные методы
handleError = (err) ->
    ###
    Default callback: if err log, stop execution
    ###
    if err
        console.log "Error".inverse.red.bold, err.toString().trim()
        #console.log err.stack if err.stack
        throw err

print = (data) -> console.log data.toString().trim()

class CmdQueue
    constructor: (title_prefix="> ", callback) ->
        ###
        Создает и настраивает очередь для команд.
        Изначально выполнение не запущено, используйте метод start.
        @param {String} title_prefix префикс, выводимый в консоль перед названием выполняемой команды. Удобно для
               выделения команд не из основной очереди.
        @param {Function} callback функция, которая выполнится при опустошении очереди. Внимание: команды из очереди
               начинают выполняться на следующий tick после добавления первой команды, и при недостаточной скорости
               добавления команд опустошение очереди может произойти больше одного раза. Для накопления команд
               перед выполнением можно использовать методы pause и resume.
        ###
        queueRunner = ({cmd, title}, cb) ->
            ###
            Выполняет одну команду из очереди.
            ###
            print (title_prefix + title).green
            cmd(cb)
        @queue = async.queue(queueRunner, 0)
        @queue.drain = callback || (-> print title_prefix + "ok".green + " all done")

    stop: () =>
        ###
        Запрещает запуск команд из очереди.
        ###
        @queue.concurrency = 0
    
    start: (concurrency=1) =>
        ###
        Запускает выполнение очереди в указанное число потоков.
        ###
        @queue.concurrency = concurrency
        @queue.process() if @queue.length()
    
    # Добавление команд в очередь
    cmd: (command, args, callback) =>
        ###
        Добавляет команду в очередь для выполнения
        @param {String|Function} команда (строка для shell-команд либо функция)
        @param {Array} args аргументы команды (передадутся аргументами shell-команде либо функции). Необязательный параметр.
        @param {Function} callback функция, которая будет вызвана после выполнения команды. Необязательный параметр (по умолчанию сделает throw ошибки).
        ###
        if 'function' == typeof args
            callback = args
            args = []

        args ?= []

        switch typeof command
            when 'string'
                # shell cmd
                title = "[exec](\"#{command}\")"
                #TODO args (не забыть про escape, в npm есть готовая библиотека)
                if args?.length
                    throw new Error("cmd() doesn't work with shell args for now. It is in TODO. Command=#{command}, args=#{args}")
                f = (cb) ->
                    exec command, cb
            when 'function'
                # function
                title = @getFunctionTitle(command, args)
                f = (cb) ->
                    command(args..., cb)
            else
                throw new Error('Command should be string or function, ' + (typeof command) + ' given')

        @queue.push {cmd: f, title: title}, callback || handleError

    getFunctionTitle: (func, args) ->
        ###
        Для переданной функции и массива аргументов строит строку,
        похожую на ту, которой эта функция была вызвана. Используется
        для более понятного описания выполняемых команд. Примеры:
        - rand("1", "10")
        - [function]("localhost")
        ###
        title = sys.inspect(func)
        if (f = title.match(/^{ \[Function: ([^\]]+)\]/)) && f[1]
            title = f[1]
        else
            title = '[function]'
        if args?.length
            title += '("' + args.join('", "').substring(0, 100) + '")'
        return title

# Экспорт
module.exports = CmdQueue

