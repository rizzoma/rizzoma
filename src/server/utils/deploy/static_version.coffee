_ = require('underscore')
path = require('path')
fs = require('fs-plus')
Conf = require('../../conf').Conf
DeployTask = require('./').DeployTask


class StaticVersion extends DeployTask
    ###
    Create versioned static files in 3 times:
        1. create revved img, js files
        2. replace uses of img to revved files in css files and create revved css files
        3. replace uses of img,js, css to revved files in html files
    ###
    constructor: (templatesDir, staticDir, prefixes=[]) ->
        super(Conf.getLogger('static-version'), templatesDir, staticDir, prefixes)
        @_staticDir = path.join(@_root, staticDir)
        @_scriptRe = /<script[^>]*\ssrc=['"]([^'"]+)["'][^>]*\/?><\/script>/gm
        @_linkRe = /<link[^>]+href=['"]([^'"]+)["']/gm
        @_imgRe = /<img[^>]+src=['"]([^'"]+)["']/gm
        @_urlRe = /url\(\s*['"]?([^'"\)#\?]+)([#\?][^'"\)]+)?["']?\s*\)/gm

    build: () =>
        ###
        Create versioned static files in 3 times:
            1. create revved img, js files
            2. replace uses of img to revved files in css files and create revved css files
            3. replace uses of img,js, css to revved files in html files
        ###
        # table of всея revved paths
        pathTable = {}
        @_logger.info("Started")
        @_logger.info("Create revved img, js files")
        pathTable = _.extend(pathTable, @_buildImgJsFiles(pathTable))
        @_logger.info("Replace uses in css and create revved css files")
        pathTable = _.extend(pathTable, @_buildCssFiles(pathTable))
        @_logger.info("Replace uses in templates")
        pathTable = _.extend(pathTable, @_buildTemplateFiles(pathTable))
        @_logger.info("Finished")

    _buildImgJsFiles: (pathTable) ->
        ###
        Create revved img, js files
        ###
        mask = '*.+(png|gif|jpg|jpeg|bmp|ico|js|xml|eot|svg|ttf|woff)'
        return @_buildFilesByMask(@_staticDir, mask, null, @_saveRevvedFile, pathTable)

    _replaceUsesInCss: (content, srcRealPath, pathTable) =>
        ###
        Replace url(...) uses
        ###
        return @_replacePath(content, @_urlRe, srcRealPath, pathTable)

    _buildCssFiles: (pathTable) ->
        ###
        Replace uses in css files and create revved css files
        @return: Object - table of paths
        ###
        return @_buildFilesByMask(@_staticDir, '*.css', @_replaceUsesInCss, @_saveRevvedFile, pathTable)

    _replaceUsesInTemplate: (content, srcRealPath, pathTable) =>
        content = @_replacePath(content, @_scriptRe, srcRealPath, pathTable)
        content = @_replacePath(content, @_linkRe, srcRealPath, pathTable)
        content = @_replacePath(content, @_imgRe, srcRealPath, pathTable)
        content = @_replaceUsesInCss(content, srcRealPath, pathTable)
        return content

    _buildTemplateFiles: (pathTable) ->
        ###
        Replace uses in template files
        ###
        htmlUsesReplacer = (content, srcRealPath, pathTable) =>
        return @_buildFilesByMask(@_templatesDir, '*.+(html|txt)', @_replaceUsesInTemplate, @_saveFile, pathTable)

    _buildFilesByMask: (rootDir, mask, usesReplacer, saver, pathTable) ->
        ###
        Replace uses and create versioned files
        @param rootDir: string - folder with processed files
        @param mask: string - mask of processed files
        @param usesReplacer: Function - (content, srcRealPath, pathTable) -> must return content
        @param saver: Function - (srcRealPath, content) ->
        ###
        pathTable = pathTable or {}
        paths = {}
        files = fs.findByMaskSync(rootDir, mask)
        for file in files
            srcRealPath = fs.realpathSync(file)
            @_logger.info("Processing file #{srcRealPath}")
            content = @_getFileContent(srcRealPath)
            content = usesReplacer(content.toString(), srcRealPath, pathTable) if usesReplacer
            stats = fs.statSync(srcRealPath)
            dstRealPath = saver(srcRealPath, content, stats)
            paths[srcRealPath] = dstRealPath
            @_logger.info("Created revved file #{dstRealPath}") if srcRealPath != dstRealPath
        return paths

    _saveRevvedFile: (srcRealPath, content, stats) =>
        ###
        create file with revved filename
        @return string - revved filename
        ###
        contentHash = @_getHash(content)
        dstRealPath = @_getDstRealPath(srcRealPath, contentHash)
        return @_saveFile(dstRealPath, content, stats)

    _getDstRealPath: (srcRealPath, contentHash) ->
        ###
        Return name of revved file
        ###
        dirname = path.dirname(srcRealPath)
        basename = path.basename(srcRealPath)
        return path.join(dirname, "#{contentHash.substr(0,8)}.#{basename}")

    _replacePath: (content, regexp, srcRealPath, pathTable) ->
        ###
        Replace all matched includes in content
        local includes became global
        @param content: string
        @param regexp: RegExp
        @param srcRealPath: string - real path to file owner of content
        ###
        curDirRealPath = path.dirname(srcRealPath)
        return content.replace(regexp, (match, src) =>
            #do not touch embedded images
            if src.match(/^data:/)
                @_logger.debug("Found use #{match.substr(0,300)}, Use is embedded data, skipping...")
                return match
            #do not touch external files
            if src.match(/\/\//)
                @_logger.debug("Found use #{match.substr(0,300)}, Use is external, skipping...")
                return match
            revvedFileRealPath = @_getRevvedFilePath(src, curDirRealPath, pathTable)
            if not revvedFileRealPath
                @_logger.debug("Found use #{match.substr(0,300)}, Can't find revved file, skipping...")
                return match
            revvedFileDstPath = @_replacePathToDstPrefix(revvedFileRealPath)
            res = match.replace(src, revvedFileDstPath)
            @_logger.debug("Found use #{match.substr(0,300)}, Replaced to #{res}")
            return res
        )

    _getRevvedFilePath: (srcPath, curDirRealPath, pathTable) ->
        realSrcPath = @_getUseRealPath(srcPath, curDirRealPath)
        return pathTable[realSrcPath]


module.exports.StaticVersion = StaticVersion