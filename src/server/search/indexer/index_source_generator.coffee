ltx = require('ltx')
async = require('async')
SearchError = require('../exceptions').SearchError
CouchSearchProcessor = require('../couch_processor').CouchSearchProcessor
Conf = require('../../conf').Conf.getSearchIndexerConf()
DOCS_LIMIT = Conf.docsAtOnce
BlipModel = require('../../blip/models').BlipModel
MergeStateProcessor = require('./state').MergeStateProcessor

class IndexSourceGenerator
    ###
    Класс, представляющий генератор исходных данных для индексации.
    ###
    constructor: () ->
        @_processedBlips = {}
        @_index = Conf.indexes.length-2

    getScheme: () ->
        BlipModel.getSearchIndexHeader().toString()

    outDeltaIndexSource: (callback) ->
        @_getIndex(@_outputUniqueBlipsXML, (err) =>
            if err
                process.stderr.write("Got error when generating delta index\n")
                process.stderr.write("#{require('util').inspect(err)}\n")
            process.stderr.write("Finished generation of delta index\n")
            callback(null)
        )

    _outputUniqueBlipsXML: (blips, callback) =>
        ###
        Выводит xml-представление ранее не выведенных блипов для поисковика
        @param blips: [blip]
        ###
        str = ""
        for blip in blips
            try
                continue if blip.id of @_processedBlips
                @_processedBlips[blip.id] = true
                curStr = "\n"
                curStr += @_getKillList(blip).toString()
                if not blip.removed
                    curStr += blip.getSearchIndex().toString()
                str += curStr
            catch e
                process.stderr.write("Got error when processing blip #{blip?.id}\n")
                process.stderr.write("#{require('util').inspect(e)}\n#{e.stack}\n")
        if process.stdout.write(str)
            callback()
        else
            process.stdout.once('drain', callback)

    _getIndex: (processXML, finish) ->
        ###
        Выбирает из базы все недавно измененные блипы и возвращает по ним xml.
        Вызывает processXML для каждой загруженной пачки блипов. Вызывает finish,
        когда обработка закончена.
        @param processXML: function
        @param finish: function
        ###
        onLastMergingTimestampGot = (err, timeFrom) =>
            return finish(new SearchError(err), null) if err
            docFrom = null
            hasNewDocs = () -> timeFrom?
            processPack = (callback) =>
                process.stderr.write("Starting process from #{new Date(timeFrom * 1000)}\n")
                @_getBlips(timeFrom, docFrom, DOCS_LIMIT, (err, blips, nextDocTime, nextDocId) =>
                    return callback(err) if err
                    timeFrom = nextDocTime
                    docFrom = nextDocId
                    processXML(blips, callback)
                )
            async.whilst(hasNewDocs, processPack, finish)
        mergingTimestamp = MergeStateProcessor.getTimestamp(@_index)
        onLastMergingTimestampGot(null, mergingTimestamp)

    _getBlips: (timeFrom, docFrom, limit, callback) ->
        ###
        Возвращает блипы со времени изменения timeFrom, начиная с блипа docFrom.
        Возвращает не более limit блипов.
        @param timeFrom: number
        @param docFrom: string
        @param limit: number
        ###
        CouchSearchProcessor.getBlipsByTimestamp(timeFrom, docFrom, limit, (err, res) =>
            return callback(err) if err
            {nextTimeFrom, nextDocFrom, blips} = res
            callback(null, blips, nextTimeFrom, nextDocFrom)
        )

    _getKillList: (blip) ->
        ###
        Создает killist для блипа.
        @param blip: BlipModel
        @returns: string
        ###
        killList = new ltx.Element('sphinx:killlist')
        killList.c('id').t(blip.getOriginalId())
        return killList

module.exports =
    IndexSourceGenerator: new IndexSourceGenerator()
    IndexSourceGeneratorClass: IndexSourceGenerator
