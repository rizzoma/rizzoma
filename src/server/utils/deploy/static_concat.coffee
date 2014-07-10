_ = require('underscore')
path = require('path')
fs = require('fs-plus')
Conf = require('../../conf').Conf
DeployTask = require('./').DeployTask


class StaticConcat extends DeployTask
    ###
    Concat static css and js files:
        1. Walk through html/txt templates
        2. Find uses and concat them (css to one combofile, js to another)
        3. Any not whitespace simbol is delimiter of combo blocks
        4. Replace uses to combo files in templates
    ###
    constructor: (templatesDir, staticDir, comboDir, prefixes=[]) ->
        super(Conf.getLogger('static-concat'), templatesDir, staticDir, prefixes)
        @_comboDir = path.join(@_root, comboDir)
        @_scriptBlockRe = /(?:\s*<script[^>]*\ssrc=['"](?:(?:\/[^\/])|[^'"\/])+\.js["'][^>]*\/?><\/script>\s*){2,}/g
        @_scriptPathRe = /['"][^'"]+\.js["']/g
        @_linkBlockRe = /(?:\s*<link[^>]+href=['"](?:(?:\/[^\/])|[^'"\/])+\.css["'][^>]*\/?>\s*){2,}/g
        @_linkPathRe = /['"][^'"]+\.css["']/g

    build: () ->
        ###
        Concat static css and js files:
            1. Walk through html/txt templates
            2. Find uses and concat them (css to one combofile, js to another)
            3. Any not whitespace simbol is delimiter of combo blocks
            4. Replace uses to combo files in templates
        ###
        @_logger.info("Started")
        fs.mkdirSync(@_comboDir, 0755) if not fs.existsSync(@_comboDir)
        templates = fs.findByMaskSync(@_templatesDir, '*.+(html|txt)')
        for templatePath in templates
            templateRealPath = fs.realpathSync(templatePath)
            @_buildTemplate(templateRealPath)
        @_logger.info("Finished")

    _buildTemplate: (templateRealPath) ->
        templateContent = @_getFileContent(templateRealPath)
        @_logger.info("Processing template #{templateRealPath}")
        stats = fs.statSync(templateRealPath)
        templateContent = @_buildTemplateCssBlocks(templateRealPath, templateContent)
        templateContent = @_buildTemplateJsBlocks(templateRealPath, templateContent)
        @_saveFile(templateRealPath, templateContent, stats)

    _buildTemplateCssBlocks: (templateRealPath, templateContent) ->
        useReplacer = '<link rel="stylesheet" href="#filename#" type="text/css" />'
        return @_buildTemplateBlocks(templateRealPath, templateContent, @_linkBlockRe, @_linkPathRe, useReplacer, "css", "")

    _buildTemplateJsBlocks: (templateRealPath, templateContent) ->
        useReplacer = '<script type="text/javascript" src="#filename#"></script>'
        return @_buildTemplateBlocks(templateRealPath, templateContent, @_scriptBlockRe, @_scriptPathRe, useReplacer, "js", ";\n")

    _buildTemplateBlocks: (templateRealPath, templateContent, blockRe, pathRe, useReplacer, ext, glue) ->
        curDirRealPath = path.dirname(templateRealPath)
        templateBlocks = templateContent.match(blockRe) or []
        @_logger.debug("Found #{templateBlocks.length} #{ext} blocks")
        for templateBlock in templateBlocks
            templateContent = @_buildTemplateBlock(templateBlock, templateContent, curDirRealPath, pathRe, useReplacer, ext, glue)
        return templateContent

    _buildTemplateBlock: (templateBlock, templateContent, curDirRealPath, pathRe, useReplacer, ext, glue) ->
        comboFileName = @_createTemplateBlockComboFile(templateBlock, curDirRealPath, pathRe, ext, glue)
        return templateContent if not comboFileName
        @_logger.debug("Created #{ext} combo #{comboFileName} from templateBlock #{templateBlock}")
        return @_replaceTemplateBlockToComboFile(templateContent, templateBlock, comboFileName, useReplacer)

    _createTemplateBlockComboFile: (templateBlock, curDirRealPath, pathRe, ext, glue) ->
        # проверка есть ли в блоке crhbgns c media != screen и если есть, то не делаем combo
        if templateBlock.search(/media=["'](?!screen['"]|all['"])\w+['"]/i) != -1
            @_logger.debug("Found #{ext} uses with media != 'screen', skipping...")
            return null
        matches = templateBlock.match(pathRe) or []
        uses = (m.substr(1, m.length-2) for m in matches)
        if not uses or uses.length <= 1
            @_logger.debug("Less than 2 #{ext} uses found in block, skipping...")
            return null
        return @_createComboFile(uses, curDirRealPath, ext, glue)

    _createComboFile: (uses, curDirRealPath, ext, glue) ->
        ###
        @return {string|null} comboFilename or null if fail
        ###
        combo =
            filename: ""
            content: ""
            stats:
                atime: null
                mtime: null
        try
            for use in uses
                combo = @_addUseToComboFile(use, combo, curDirRealPath, glue)
        catch e
            # if one of uses is not found do not create combos
            @_logger.warn(e)
            return null
        combo.filename = path.join(@_comboDir, "#{@_getHash(combo.filename)}.#{ext}")
        return @_saveFile(combo.filename, combo.content, combo.stats)

    _addUseToComboFile: (use, combo, curDirRealPath, glue) ->
        ###
        Collect use content filename and stats to combo content filename and stats
        ###
        # find use file
        useRealPath = @_getUseRealPath(use, curDirRealPath)
        throw new Error("Can't find usage file #{use} realpath: #{useRealPath}") if not fs.existsSync(useRealPath)
        # collect combo content
        combo.content += glue
        combo.content += "\n/***** content of #{use} *****/\n"
        combo.content += @_getFileContent(useRealPath)
        # collect combo filename
        combo.filename += useRealPath
        # collect combo times
        stats = fs.statSync(useRealPath)
        if not combo.stats.atime or combo.stats.atime.getTime() < stats.atime.getTime()
            combo.stats.atime = stats.atime
        if not combo.stats.mtime or combo.stats.mtime.getTime() < stats.mtime.getTime()
            combo.stats.mtime = stats.mtime
        return combo

    _replaceTemplateBlockToComboFile: (templateContent, templateBlock, comboFileName, useReplacer) ->
        comboDstFilePath = @_replacePathToDstPrefix(comboFileName)
        useReplacer = useReplacer.replace("#filename#", comboDstFilePath)
        return templateContent.replace(templateBlock, useReplacer)

    _getFileContent: (filename) ->
        content = super(filename)
        return if content then content.toString() else null

    _getConcatTable: (content, regexp) ->
        ###
        Replace all matched includes in content
        local includes became global
        @param content: string
        @param regexp: RegExp
        @param srcRealPath: string - real path to file owner of content
        ###
        concatTable = []
        concatParts = content.split(@_concatDelimiter)
        for concatPart in concatParts
            matches = concatPart.match(regexp)
            continue if not matches or matches.length <= 1
            uses = []
            for match in matches
                #do not touch external files
                continue if match.match(/\/\//)
                uses.push(match)
            concatTable.push(uses) if uses and uses.length > 1
        return concatTable


module.exports.StaticConcat = StaticConcat