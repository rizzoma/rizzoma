_ = require('underscore')
child_process = require('child_process')

class ProcessUtils
    ###
    Утилиты для работы с процессами.
    ###
    constructor: () ->

    spawn: (cmd, args=[], env={}, listeners={}, callback) =>
        ###
        Создает новый процесс.
        @param cmd: string - что выполнить
        @param args: array - аргументы для cmd
        @param env: object - переменные окружения, которые будут переданы в процесс
        @param listeners: object
            out: function(data) - обработчик stdout
            err: function(data) - обработчик stderr
        @param callback: function
        ###
        stdoutListener = listeners.out or @_print
        stderrListener = listeners.err or @_print
        appEnv = _.clone(process.env)
        _.extend(appEnv, env)
        app = child_process.spawn(cmd, args, {env: appEnv})
        app.stdout.on('data', stdoutListener)
        app.stderr.on('data', stderrListener)
        app.on('exit', (code) ->
            callback?(code != 0)
        )

    _print: (data) ->
        ###
        Приводит объект к строке и отдает в stdout.
        @param data: object
        ###
        console.log(data.toString().trim())

module.exports.ProcessUtils = new ProcessUtils()
