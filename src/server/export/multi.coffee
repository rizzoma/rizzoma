_ = require('underscore')
async = require('async')
loadMarkup = require('./controller').loadMarkup
Conf = require('../conf').Conf
{AmqpAdapter, AmqpQueueListener} = require('../common/amqp')
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
fs = require('fs-plus')
getFileName = require('./utils').getFileName
path = require('path')
toHtml = require('rizzoma-export').toHtml
zip = require('node-zip')
os = require('os')
getFileNameTimestamp = require('./utils').getFileNameTimestamp
IdUtils = require('../utils/id_utils').IdUtils

ROUTING_KEY = 'export'

logger = Conf.getLogger('export')

class AmqpListener
    
    constructor: (@_callback) ->

    _onMessage: (message, headers, deliveryInfo, callback) =>
        task = JSON.parse(message.data)
        @_callback(null, task, (error) ->
            callback(error, true)
        )
        
    _getConnector: ->
        options =
            listenRoutingKey: ROUTING_KEY
            listenCallback: @_onMessage
            listenQueueAutoDelete: false
            listenQueueAck: true
        _.extend(options, Conf.getAmqpConf())
        return new AmqpQueueListener(options)
        
    connect: ->
        connector = @_getConnector()
        connector.connect()

getUserArchivePath = (userId) ->
    return path.join(Conf.getExportConf().archivePath, userId)
        
class ArchiveBuilder
    
    RANDOM_HASH_LENGTH: 16
    
    _exportWaveToArchive: (user, waveUrl, archive, callback) ->
        tasks = [
            (callback) ->
                loadMarkup(user, waveUrl, callback)
            (markup, callback) ->
                offset = 0
                data = toHtml(markup, {offset})
                archive.file(getFileName(markup.title, 'htm', offset), data)
                callback()
        ]
        async.waterfall(tasks, (error) ->
            callback(null, not error)
        )
        
    _exportWavesToArchive: (user, waveUrls, callback) ->
        archive = zip()
        tasks = []
        for waveUrl in waveUrls
            tasks.push(do (waveUrl) =>
                return async.apply(@_exportWaveToArchive, user, waveUrl, archive)
            )
        async.parallel(tasks, (error, results) ->
            topics = _.filter(results, (item) -> return item).length
            if not topics
                return callback('no topics exported')
            callback(error, archive, topics)
        )
        
    _prepareArchive: (archive, callback) ->
        data = archive.generate(
            base64: false
            compression: 'DEFLATE'
        )
        random = IdUtils.getRandomId(@RANDOM_HASH_LENGTH)
        tempPath = path.join(os.tmpDir(), "export-#{random}")
        fs.writeFile(tempPath, data, 'binary', (error) ->
            callback(error, tempPath)
        )
    
    _getArchivePath: (user, topics) ->
        timestamp = getFileNameTimestamp(0)
        random = IdUtils.getRandomId(@RANDOM_HASH_LENGTH)
        return path.join(getUserArchivePath(user.id), random, "export-#{timestamp}-#{topics}.zip")
        
    _saveArchive: (tempPath, user, topics, callback) ->
        newPath = @_getArchivePath(user, topics)
        fs.mkdirp(path.dirname(newPath), (error) ->
            return callback(error) if error
            fs.rename(tempPath, newPath, callback)
        )

    build: (user, waveUrls, callback) ->
        vars = {}
        tasks = [
            (callback) =>
                @_exportWavesToArchive(user, waveUrls, callback)
            (archive, topics, callback) =>
                vars.topics = topics
                @_prepareArchive(archive, callback)
            (tempPath, callback) =>
                @_saveArchive(tempPath, user, vars.topics, callback)
        ]
        async.waterfall(tasks, callback)

class MultiExporter

    MAX_COUNT: 100
    
    _onNewTask: (error, task, callback) =>
        count = task.waveUrls.length
        logger.info("starting new task for user #{task.userId} and #{count} topics")
        if count > @MAX_COUNT
            logger.warning("can't export #{count} topics because of max count is #{@MAX_COUNT}")
            return callback()
        pathToLock = path.join(getUserArchivePath(task.userId), 'lock')
        tasks = [
            (callback) ->
                fs.exists(pathToLock, (isFound) ->
                    callback("lock file #{pathToLock} found, skipping task" if isFound)
                )
            (callback) ->
                fs.mkdirp(path.dirname(pathToLock), callback)
            (callback) ->
                fs.writeFile(pathToLock, '', callback)
            (callback) ->
                UserCouchProcessor.getById(task.userId, callback)
            (user, callback) ->
                builder = new ArchiveBuilder()
                builder.build(user, task.waveUrls, callback)
        ]
        async.waterfall(tasks, (error) ->
            if error
                logger.warn(error)
            fs.unlink(pathToLock, (error) ->
                if error
                    logger.debug("can't remove lock file: #{error}", {pathToLock: pathToLock, err: error})
            )
            logger.info('task done')
            callback(error)
        )

    run: ->
        listener = new AmqpListener(@_onNewTask)
        listener.connect()

exports.exporter = new MultiExporter()

exports.addExportTask = (userId, waveUrls, callback) ->
    amqp = new AmqpAdapter(Conf.getAmqpConf())
    amqp.connect( ->
        amqp.publish(ROUTING_KEY, JSON.stringify(
            userId: userId
            waveUrls: waveUrls
        ))
        callback()
    )

class ArchiveFinder

    constructor: (@_userId, @_callback) ->
        @_hasTask = false
        @_archives = []
        @_directory = getUserArchivePath(@_userId)
    
    _getArchiveInfoByFileName: (fileName) ->
        matches = fileName.match(/^export-(\d+)-(\d+)-(\d+)\((\d+)-(\d+)(\w+)\)-(\d+)/)
        created = "#{matches[1]}-#{matches[2]}-#{matches[3]} #{matches[4]}:#{matches[5]}#{matches[6]}"
        topics = parseInt(matches[7])
        return {
            created: created
            topics: topics
        }
        
    _getArchiveUrl: (pathToFile) ->
        relativePath = pathToFile.replace(new RegExp("^#{@_directory}"), '')
        return path.join(@_userId, relativePath)
        
    _doCallback: (error) =>
        return @_callback(error) if error
        @_callback(null,
            hasTask: @_hasTask
            archives: @_archives[0..2]
        )
        
    _onFinderFile: (pathToFile, stat) =>
        fileName = path.basename(pathToFile)
        if fileName is 'lock'
            @_hasTask = true
        else
            info = @_getArchiveInfoByFileName(fileName)
            info.url = @_getArchiveUrl(pathToFile)
            info.timestamp = stat.mtime
            @_archives.push(info)
    
    _prepareArchiveList: ->
        @_archives.sort((a, b) ->
            return if a.timestamp < b.timestamp then 1 else -1
        )
        for archive in @_archives
            delete archive.timestamp
        
    _onFinderEnd: =>
        @_prepareArchiveList()
        @_doCallback()

    find: ->
        fs.exists(@_directory, (isFound) =>
            return @_doCallback() if not isFound
            finder = fs.find(@_directory)
            finder.on('error', @_doCallback)
            finder.on('file', @_onFinderFile)
            finder.on('end', @_onFinderEnd)
        )

exports.findArchives = (userId, callback) ->
    finder = new ArchiveFinder(userId, callback)
    finder.find()
