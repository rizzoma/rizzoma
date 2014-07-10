fs = require('fs')
Conf = require('../../conf').Conf.getSearchIndexerConf()
DateUtils = require('../../utils/date_utils').DateUtils

class MergeStateProcessor
    ###
    Загружает и сохранаяет состояние при мердже индексов
    ###
    _getStateFilePath: (index) ->
        return "#{Conf.indexesPath}/#{Conf.indexPrefix}_#{index}/merge_state.txt"

    getTimestamp: (index) ->
        ###
        Достает timestamp последнего merge индекса
        ###
        stateFilePath = @_getStateFilePath(index)
        return 0 if not fs.existsSync(stateFilePath)
        return parseInt(fs.readFileSync(stateFilePath, "utf8"))

    updateTimestamp: (index, time=DateUtils.getCurrentTimestamp()-5) ->
        ###
        Обновляет время merge индекса
        ###
        stateFilePath = @_getStateFilePath(index)
        fs.writeFileSync(stateFilePath, time)

class BackupStateProcessor extends MergeStateProcessor
    ###
    Загружает и сохранаяет состояние при бэкапе индексов
    ###
    _getStateFilePath: (index) ->
        return "#{Conf.indexesPath}/#{Conf.indexPrefix}_#{index}/backup_state.txt"

module.exports =
    MergeStateProcessor: new MergeStateProcessor()
    BackupStateProcessor: new BackupStateProcessor()