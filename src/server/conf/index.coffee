###
Config manager: загружает настройки из settings.coffee и settings_local.coffee,
хранит соединения с БД, ...
###

try
    settings = require('../settings_local')
catch e
    if /^Cannot find module /.test(e.message)
        console.error('Hint: create settings_local.coffee with local config. Copy and modify src/server/settings_local.coffee.template')
        settings = require('../settings')
    else
        throw e

# получаем название окружения (env) из NODE_ENV
env = process.env.NODE_ENV || "dev"

# получаем настройки для env
throw new Error("No settings for env=#{env} in settings.coffee or settings_local.coffee") if !(env of settings)
settings = settings[env]

# создаем объект с настройками и методами работы с ними
conf = new (require('./conf'))(settings)

# экспортируем (с заглавной буквы (?), т.к. синглтоны)
module.exports = 
    Conf: conf
    Env: env
