path = require('path')
fs = require('fs-plus')
Conf = require('../../conf').Conf
{DeployTask} = require('./')

class AuthForm extends DeployTask
    ###
    Бегает по html файлам, заменяет <!-- ~auth~ --> на форму авторизации
    ###
    constructor: (workingDir, templatesDir) ->
        super(Conf.getLogger('auth-form'), templatesDir, "")
        @_workingDir = path.join(@_root, workingDir)
        # плэйсхолдер который заменится на форму авторизации
        @_authPlaceholderRe = /<!--\s*~auth~\s*-->/g
        templatePath = path.join(@_templatesDir, "auth/index.html")
        @_authFormTemplate = fs.readFileSync(templatePath) + "\n"
        @_authFormTemplate += '<script type="text/javascript">window.AuthDialog.init(true);</script>'

    build: () =>
        ###
        ###
        @_logger.info("Started")
        @_logger.info("Replace uses in html")
        files = fs.findByMaskSync(@_workingDir, '*.html')
        for file in files
            @_logger.info("Processing file #{file}")
            content = @_getFileContent(file).toString()
            content = @_replacePlaceholdersByForm(content)
            stats = fs.statSync(file)
            dstRealPath = @_saveFile(file, content, stats)
        @_logger.info("Finished")

    _replacePlaceholdersByForm: (content) ->
        return content.replace(@_authPlaceholderRe, @_authFormTemplate)


module.exports.AuthForm = AuthForm