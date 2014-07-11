path = require('path')
fs = require('fs-plus')
crypto = require('crypto')

class DeployTask
    ###
    Base class for deploying tasks
    ###
    constructor: (@_logger, templatesDir, staticDir, @_prefixes=[]) ->
        @_root = path.join(__dirname,'../../../../')
        if not @_prefixes or not @_prefixes.length
            @_prefixes = [{
                srcPrefix: '/',
                realPath: staticDir,
                dstPrefix: '/'
            }]
        @_templatesDir = path.join(@_root, templatesDir)
        @_staticDir = path.join(@_root, staticDir)

    _getFileContent: (filename) ->
        try
            return fs.readFileSync(filename)
        catch e
            @_logger.error("Can't read #{filename}", e)
            return null

    _saveFile: (dstPath, content, stats) =>
        ###
        Save content in file
        ###
        fs.writeFileSync(dstPath, content)
        fs.utimesSync(dstPath, stats.atime, stats.mtime) if stats
        return dstPath

    _getHash: (str) =>
        ###
        Return md5 hash of str
        ###
        return crypto.createHash("md5").update(str).digest("hex")

    _getUseRealPath: (srcPath, curDirRealPath) ->
        if srcPath.search("/") != 0
            realSrcPath = path.join(curDirRealPath, srcPath)
        else
            realSrcPath = srcPath
            for conf in @_prefixes
                realRealPath = path.join(@_root, conf.realPath)
                realSrcPath = realSrcPath.replace(conf.srcPrefix, realRealPath)
        return realSrcPath

    _replacePathToDstPrefix: (fileRealPath) ->
        fileDstPath = fileRealPath
        for conf in @_prefixes
            realRealPath = path.join(@_root, conf.realPath)
            fileDstPath = fileRealPath.replace(realRealPath, conf.dstPrefix)
        return fileDstPath

module.exports.DeployTask = DeployTask