#!/usr/bin/env coffee
###
Главная запсускалка всего и вся
Роли (приложения) находятся в папке app_roles
Пример запуска роли 
По умолчанию запускается роль default с приложениями (ролями) web_main и wave и другими.
примеры запуска:
    APP_ROLES=mainpage,import cake run
    APP_ROLES=mainpage,import ./src/server/app.coffee
    cake run
###

# add time marks into stdout and stderr (should be before requiring Conf)
start_mark = "#{new Date()} -- Starting server --\n"
process.stdout.write(start_mark)
process.stderr.write(start_mark)

# conf
_ = require('underscore')
Conf = require('./conf').Conf

process.on('exit', (err) ->
    Conf.getLogger('process').info('Server stopped')
)
process.on('uncaughtException', (err) ->
    Conf.getLogger('process').error('[Uncaught exception]', err)
    process.nextTick ->
        process.exit(1)
)

# start roles
for role in Conf.getAppRoles()
    try
        require("./app_roles/#{role}")
    catch e
        if e.message.indexOf("Cannot find module './app_roles/#{role}'") == 0
            Conf.getLogger('process').error("Unknown role #{role}")
        throw e

do () ->
    roles = Conf.getAppRoles()
    appBranch = Conf.getVersionInfo().branch or '-'
    appVersion = Conf.getVersion() or '-'
    Conf.getLogger('process').info("Server (#{roles.join('+')}) started. Version is #{appVersion}.", {roles, appBranch, appVersion})
