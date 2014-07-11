fs = require('fs')
path = require('path')
Conf = require('../../../conf').Conf.getSearchIndexerConf()
class StateProcessor
    ###
    Загружает и сохранаяет состояние при полной переиндексации
    ###
    constructor: () ->
        @_stateFilePath = Conf.stateFilePath or "/var/lib/sphinxsearch/full/full-indexing-state.txt"

    getState: () ->
        state =
            processed: -1
            startId: "0_b_0"
        return state if not fs.existsSync(@_stateFilePath)
        content = fs.readFileSync(@_stateFilePath)
        return JSON.parse(content)

    saveState: (blips) ->
        ###
        @param blips: array - массив проиндексированных блипов
        ###
        stat =
            processed: blips.length
            startId: if blips.length then blips[blips.length-1].id else "0_b_{"
        fs.writeFileSync(@_stateFilePath, JSON.stringify(stat))

module.exports.StateProcessor = new StateProcessor()