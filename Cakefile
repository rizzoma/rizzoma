exec  = require('child_process').exec
spawn = require('./src/server/utils/process_utils').ProcessUtils.spawn
async = require('async')
path = require('path')
require 'colors' # colorize terminal output
# file utils
fs = require 'fs-plus'
# object utils
_ = require 'underscore'
StaticVersion = require('./src/server/utils/deploy/static_version').StaticVersion
Conf = require('./src/server/conf').Conf

# Вспомогательные методы
handleError = (err) ->
    if err
        console.log "Error".inverse.red.bold
        console.log err.stack if err.stack

handleOutput = (err, stdout, stderr) ->
    handleError err
    console.log stdout, stderr?.white?.inverse

handleNone = ->

print = (data) -> console.log data.toString().trim()

# Очередь команд
CmdQueue = require('./src/server/utils/cake_commands')
cmd_queue = new CmdQueue
cmd_queue.start()
cmd = cmd_queue.cmd

# Добавляет в очередь команд завершение процесса с небольшим ожиданием перед этим, чтобы асинхронные вызовы (например, отправка логов по сети) успели завершиться.
# принудительное завершение процесса нужно из-за остающихся после выполнения листенеров (например, чтобы выходил при включенном кеше).
cmd_exit_soon = () ->
    cmd (callback) ->
        setTimeout(
            () -> process.exit(0)
        , 1000)

# Project structure
root = path.resolve(__dirname)
bin = "#{root}/node_modules/.bin/"

# Задачи сборки
task 'build', 'Build server and client code', ->
    invoke "build-server"
    invoke "build-client"
    invoke "generate-search-scheme"

option '', '--do-not-compile-server', 'Do not cimpile server scripts to js'
task 'build-server', 'Compile server side code to javascript', (options)->
    invoke 'clean-server'

    # 1. compile CoffeeScript
    folders = []
    folders.push('server') if not options['do-not-compile-server']
    folders.push('share')
    for d in folders
        src = "#{root}/src/#{d}"
        out = "#{root}/lib/server/#{d}"
        cmd fs.mkdirp, [out, 0755]
        cmd "#{bin}coffee -c -o #{out} #{src}"

    # 2. push CouchDB views and handlers
    invoke "couch-push-all"

    # 3. process node_modules
    invoke 'build-node_modules'

task 'build-client', 'Compile client side code to javascript, run Browserify, copy static, minify', ->
    invoke 'clean-client'

    # 1. compile CoffeeScript
    for d in ['client', 'share']
        src = "#{root}/src/#{d}"
        out = "#{root}/lib/client/#{d}"
        cmd fs.mkdirp, [out, 0755]
        cmd "#{bin}coffee -c -o #{out} #{src}"
    cmd "#{bin}coffee -c -o #{root}/lib/client/ #{root}/src/*_index.coffee"

    # 2. copy static
    cmd fs.mkdirp, ["#{root}/lib/static", 0755]
    cmd fs.cpr, ["#{root}/src/static", "#{root}/lib/static"]

    # 2.5 copy auth script to static
    cmd fs.cpr, ["#{root}/lib/client/client/auth/index.js", "#{root}/lib/static/js/auth.js"]

    # 3. copy pulse static
    cmd fs.mkdirp, ["#{root}/lib/static/pulse", 0755]
    cmd fs.cpr, ["#{root}/lib/client/client/pulse", "#{root}/lib/static/pulse"], handleNone

    # 4. Browserify
    cmd fs.mkdirp, ["#{root}/lib/static/js", 0755]
    cmd "#{bin}browserify #{root}/lib/client/client_index.js -o #{root}/lib/static/js/index.js"
    cmd "#{bin}browserify #{root}/lib/client/mobile_index.js -o #{root}/lib/static/js/mobile_index.js"
    cmd "#{bin}browserify #{root}/lib/client/pulse_index.js -o #{root}/lib/static/js/pulse_index.js", handleNone
    cmd "#{bin}browserify #{root}/lib/client/settings_index.js -o #{root}/lib/static/js/settings_index.js"

    # 5. Delete .svn (since lib, build children not in svn)
    clean_dir = (r, cb) ->
        r = "#{root}/#{r}"
        dirs = []
        remove_dirs = ->
            if dirs.length
                q = new CmdQueue(">> ", cb)
                q.cmd(fs.rmr, [r]) for r in dirs
                q.start(10)
            else
                cb()

        fs.find(r).on('error', cb).on('end', remove_dirs).on('directory', (dir) ->
            dirs.push(dir) if (dir != "#{r}/.svn" && /[/\\]\.svn$/.test(dir))
        )

    cmd(clean_dir, ["lib"])

    # 6. lint, minify, compress, static versions

    # 7. ShareJS client files
    cmd fs.cpr, ["#{root}/node_modules/share/webclient/share.uncompressed.js", "#{root}/lib/static/js/share.uncompressed.js"]

task 'build-client-fast', 'Build client side code without additional checks', ->
    # Copy static
    filter = (name) ->
        name.indexOf('.svn') == -1
    cmd fs.cpr, ["#{root}/src/static", "#{root}/lib/static", {limit: 512, filter: filter}]

    # 2.5 copy auth script to static
    cmd fs.cpr, ["#{root}/lib/client/client/auth/index.js", "#{root}/lib/static/js/auth.js"]

    # Browserify
    cmd "#{bin}browserify #{root}/src/client_index.coffee -o #{root}/lib/static/js/index.js"
    cmd "#{bin}browserify #{root}/src/mobile_index.coffee -o #{root}/lib/static/js/mobile_index.js"
    cmd "#{bin}browserify #{root}/src/pulse_index.coffee -o #{root}/lib/static/js/pulse_index.js", handleNone
    cmd "#{bin}browserify #{root}/src/settings_index.coffee -o #{root}/lib/static/js/settings_index.js"

    # Copy ShareJS client files
    cmd fs.cpr, ["#{root}/node_modules/share/webclient/share.uncompressed.js", "#{root}/lib/static/js/share.uncompressed.js"]

task 'build-sharejs', 'Build node_modules/sharejs module, for client and server', ->
    # 1. build ShareJS server part
    cmd "cd ./node_modules/share/ && PATH=#{bin}:$PATH cake build", [], handleOutput

    # 2. ShareJS client files
    cmd "cd ./node_modules/share/ && PATH=#{bin}:$PATH cake webclient", [], handleOutput

task 'build-tests', 'Build tests, including cucumis scenarios', ->
    # 1. clean old build
    invoke 'clean-tests'

    # 2. build coffee files
    cmd "#{bin}coffee -c -o #{root}/lib/tests/ #{root}/src/tests"

    # 3. copy .feature files for cucumis
    cmd fs.cpr, ["#{root}/src/tests/share/features", "#{root}/lib/tests/share/features"]

task 'build-node_modules', 'Configure node_modules, symlink compiled modules', ->
    cmd "#{root}/bin/symlink_compiled_node_modules.sh", [], handleOutput

task 'build-pages', 'Build static pages', ->
    # Copy pages and static files
    filter = (name) ->
        name.indexOf('.svn') == -1 and name.indexOf('Thumbs.db') == -1
    cmd fs.cpr, ["#{root}/src/pages", "#{root}/lib/pages", {limit: 1024, filter: filter}]

task 'clean', 'Clean build directories', ->
    invoke 'clean-server'
    invoke 'clean-client'
    invoke 'clean-tests'

task 'clean-server', 'Clean build directories for server', ->
    cmd(fs.rmr, ["#{root}/#{r}"]) for r in ["lib/server"]

task 'clean-client', 'Clean build directories for client', ->
    cmd(fs.rmr, ["#{root}/#{r}"]) for r in ["lib/client", "lib/static"]

task 'clean-tests', 'Clean build directories for tests', ->
    cmd(fs.rmr, ["#{root}/#{r}"]) for r in ["lib/tests"]

task 'clean-pages', 'Clean build directories for static pages', ->
    cmd(fs.rmr, ["#{root}/#{r}"]) for r in ["lib/pages"]

task 'init', 'Configure system for first run, (re-)create Sphinx search indexes', ->
    # 1. build
    invoke 'build'

    # 2. create database, push views
    invoke 'couch-push-all'

    # 3. create settings_local.coffee
    cmd (callback) ->
        file = "#{root}/src/server/settings_local.coffee"
        fs.stat file, (err, stat) ->
            if not err and stat and stat.isFile()
                print "Don't forget: file src/server/settings_local.coffee is a good place for local config.".yellow.inverse
                return callback()
            fs.cpr "#{file}.template", file, (err) ->
                print "File src/server/settings_local.coffee created. This is a good place for local config.".yellow.inverse
                callback(err)

    # 4. (re-)create Sphinx search indexes
    # Note: add user who run cake init to sudoers
    env = {INDEX_PREFIX: Conf.getSphinxIndexPrefix()}

    # automatic indexes remove is disabled, do it by hand
    #cmd (callback) ->
    #    spawn('sudo', ["#{root}/bin/remove_sphinx_indexes.sh", process.env.USER], env, null, callback)

    # 6. (re-)create Sphinx search indexes
    cmd (callback) ->
        spawn('sudo', ["#{root}/bin/init_sphinx_indexer.sh", process.env.USER], env, null, callback)

option '-d', '--debug', "Run node.js in debug mode, also starts node-inspector if it wasn't started yet"
option null, '--debug-brk', "Run node.js in debug mode and stop on first line, also starts node-inspector if it wasn't started yet"
option null, '--fast-start', "Run without server files check compiling"
option null, '--skip-client-build', "Skip building of client files (works only with --fast-start)"

task 'run-node-inspector', 'Start node-inspector if it is not running', ->
    # Note: Cakefile will not end after app.coffee exit so press Ctrl+C (or start node-inspector separately)
    cmd (callback) ->
        listener = (data) ->
            print(">> debug: " + data)
        listeners =
            err: listener
            out: listener
        app = spawn("#{root}/bin/run_node_inspector.sh", null, null, listeners, () ->
            # return early as we are running in background
            callback()
        )

# Параметры запуска
option '-l', '--log_level [LOG_LEVEL]', 'ALL, TRACE, DEBUG, INFO, WARN, ERROR, FATAL, OFF'

task 'run', 'Run server', (options) ->
    if options['fast-start']
        invoke 'build-client-fast' if not options['skip-client-build']
    else
        invoke 'build'

    invoke 'run-node-inspector' if options['debug'] or options['debug-brk']

    cmd (callback) ->
        args = []
        args.push('--nodejs', '--debug') if options['debug']
        args.push('--nodejs', '--debug-brk') if options['debug-brk']
        args.push("#{root}/src/server/app.coffee")
        env = {LOG_LEVEL: options.log_level or ''}
        app = spawn("#{bin}coffee", args, env, null, callback)

    cmd_exit_soon()

task 'run-weekly-digest-notificator', 'Run weekly digest notificator', (options) ->
    cmd (callback) ->
        require('./src/server/changes_digest').WeeklyChangesDigestNotificator.run(callback)
    cmd_exit_soon()

task 'run-daily-digest-notificator', 'Run daily digest notificator', (options) ->
    cmd (callback) ->
        require('./src/server/changes_digest').DailyChangesDigestNotificator.run(callback)
    cmd_exit_soon()

task 'run-plugin-autosender', 'Run notification autosending for all plugins', (options) ->
    cmd (callback) ->
        require('./src/server/blip/plugin_autosender_manager').PluginAutosendManager.run(callback)
    cmd_exit_soon()

task 'run-first-visit-notificator', 'Run first visit notificator', (options) ->
    cmd (callback) ->
        require('./src/server/user/first_visit_notificator').FirstVisitNotificator.run(callback)
    cmd_exit_soon()

task 'run-blip-comment-notificator', 'Run blip comment notificator', (options) ->
    ###
    Уведомлялка об ответе на твой блип
    ###
    cmd (callback) ->
        require('./src/server/blip/comment_notificator').CommentNotificator.run(callback)
    cmd_exit_soon()

task 'run-email-reply-fetcher', 'Run email reply fetcher, read emails and import reply to rizzoma', (options) ->
    ###
    Читает письма и создает реплаи в топиках
    ###
    cmd (callback) ->
        require('./src/server/blip/email_reply_fetcher/index').EmailReplyFetcher.run(callback)
    cmd_exit_soon()

task 'run-file-cleaner', 'Clean files with missing links', ->
    cmd (callback) ->
        FileCleaner = require('./src/server/file/file_cleaner.coffee').FileCleaner
        fileCleaner = new FileCleaner()
        fileCleaner.run(callback)
    cmd_exit_soon()

###
Создает файлы ошибок для Haproxy (добавляет HTTP-заголовки в HTML-файлы ошибок)
###
task 'build-errorpages', 'Build .http pages for Haproxy', (options) ->
    # source and destinations
    pages = [
        {src: '503.html', dest: [
            {code: '502', msg: 'Bad Gateway'}, {code: '503', msg: 'Service Unavailable'}, {code: '504', msg: 'Gateway Time-out'}
        ]}
    ]
    CRLF = "\r\n"
    headers = "#{CRLF}Cache-Control: no-cache#{CRLF}Connection: close#{CRLF}Content-Type: text/html#{CRLF}#{CRLF}"
    outDir = "#{root}/lib/static/errorpages"

    cmd fs.mkdirp, [outDir, 0755]

    cmd (cmd_callback) ->
        async.waterfall([
            (callback) ->
                # read source files
                readSource = (item, callback) ->
                    fs.readFile "#{root}/src/server/templates/#{item.src}", (err, text) ->
                        # minify and save page source text
                        item.srcText = text.toString().trim().replace(/\s*\n\s*/g, "\n")
                        callback(err, item)
                async.map(pages, readSource, callback)
            , (pages, callback) ->
                # create destination files
                #console.log pages
                out = []
                for page in pages
                    # .html file
                    out.push {file: page.src, text: page.srcText}
                    # .http files
                    for dest in page.dest
                        text = "HTTP/1.0 #{dest.code} #{dest.msg}#{headers}"
                        # big page (for users)
                        out.push {file: "#{dest.code}.http", text: text + page.srcText}
                        # small page
                        out.push {file: "#{dest.code}_mini.http", text: text + "#{dest.code} #{dest.msg}"}
                callback(null, out)
            , (out, callback) ->
                # write destination files
                saveFile = (item, callback) ->
                    fs.writeFile("#{outDir}/#{item.file}", item.text, callback)
                async.forEach(out, saveFile, callback)
        ], cmd_callback)

###
Gzip для файлов в lib/static/, для раздачи через модуль nginx gzip_static
###
task 'build-static-gzip', 'Gzip static files', (options) ->
    cmd "#{root}/bin/build_static_gzip.sh static", [], handleOutput

###
Gzip для файлов в lib/pages/, для раздачи через модуль nginx gzip_static
###
task 'build-pages-gzip', 'Gzip static pages', (options) ->
    cmd "#{root}/bin/build_static_gzip.sh pages", [], handleOutput


###
Удаление каталога с версионированными шаблонами
lib/templates/ .
###
task 'сlean-server-templates', 'Remove catalog with versioned template files', (options) ->
    cmd(fs.rmr, ["#{root}/lib/templates"])

###
Копирует шаблоны из src/templates в lib/templates/
###
task 'build-server-templates', 'Copy server templates to lib/templates/', (options) ->
    invoke 'сlean-server-templates'
    cmd fs.mkdirp, ["#{root}/lib/templates", 0755]
    filter = (name) ->
        name.indexOf('.svn') == -1
    cmd fs.cpr, ["#{root}/src/server/templates", "#{root}/lib/templates", {limit: 512, filter: filter}]

###
Версионирование статики и шаблонов
в lib/static/ и lib/templates/
###
task 'build-static-version', 'Version static and template files', (options) ->
    cmd (callback) ->
        sv = new StaticVersion('lib/templates/', 'lib/static/', [{
            srcPrefix: '/s/',
            realPath: 'lib/static/',
            dstPrefix: '/s/'
        }])
        sv.build()
        callback()

###
Версионирование статики и html-файлов для статических страниц
в lib/pages
###
task 'build-pages-static-version', 'Build static pages versions', ->
    cmd (callback) ->
        sv = new StaticVersion('lib/pages/', 'lib/pages/')
        sv.build()
        callback()

task 'build-pages-auth', 'Replace placeholder <!-- ~auth~ --> with auth form in pages', (options) ->
    {AuthForm} = require('./src/server/utils/deploy/auth_form')
    cmd (callback) ->
        af = new AuthForm('lib/pages/', 'lib/templates/')
        af.build()
        callback()

task 'deploy-fix-times', 'fix static times', ->
    cmd "#{root}/bin/utimes.sh #{root}/src/static #{root}/lib/static", [], handleOutput
    cmd "touch --reference=#{root}/node_modules/share/webclient/share.uncompressed.js #{root}/lib/static/js/share.uncompressed.js", [], handleOutput
    cmd "#{root}/bin/utimes.sh #{root}/src/server/templates #{root}/lib/templates", [], handleOutput

task 'deploy-pages-fix-times', 'fix static times', ->
    cmd "#{root}/bin/utimes.sh #{root}/src/pages #{root}/lib/pages", [], handleOutput

StaticConcat = require('./src/server/utils/deploy/static_concat').StaticConcat
task 'build-static-concat', 'concatenate static files', ->
    cmd (callback) ->
        sc = new StaticConcat('lib/templates/', 'lib/static/', 'lib/static/combo/', [{
            srcPrefix: '/s/',
            realPath: 'lib/static/',
            dstPrefix: '/s/'
        }])
        sc.build()
        callback()

task 'build-pages-static-concat', 'concatenate pages static files', ->
    cmd (callback) ->
        sc = new StaticConcat('lib/pages/', 'lib/pages/', 'lib/pages/s/page/combo/')
        sc.build()
        callback()


###
Подготовка к запуску обновленного кода в production
###
task 'deploy', 'Build, push views, prepare for production run', (options) ->
    # save previous static files to prevent 404's at build time
    cmd "rm -rf #{root}/lib/static-previous ; if [ -d #{root}/lib/static ] ; then cp -r --preserve=mode,ownership,timestamps #{root}/lib/static #{root}/lib/static-previous ; fi"
    # build and deploy
    invoke 'build'
    invoke 'build-version'
    invoke 'couch-push-all'
    invoke 'build-errorpages'
    #invoke 'build-static-minify'
    invoke 'build-server-templates'
    invoke 'deploy-fix-times'
    invoke 'build-static-version'
    invoke 'build-static-concat'
    invoke 'build-static-gzip'
    invoke 'deploy-pages' # this task calls process.exit after run

###
Подготовка к запуску обновленного кода статических страниц в production
###
task 'deploy-pages', 'Build static pages, prepare for production run', (options) ->
    # save previous static pages files before clean-pages to prevent 404 errors at build time
    cmd "rm -rf #{root}/lib/pages-previous ; if [ -d #{root}/lib/pages ] ; then cp -r --preserve=mode,ownership,timestamps #{root}/lib/pages #{root}/lib/pages-previous ; fi"
    invoke 'clean-pages'
    invoke 'build-pages'
    invoke 'build-pages-auth'
    invoke 'deploy-pages-fix-times'
    invoke 'build-pages-static-version'
    invoke 'build-pages-static-concat'
    invoke 'build-pages-gzip'
    cmd_exit_soon()

###
Команды тестирования
    test - запускает unit-тесты с помощью nodeunit
    test-cucumis - запускает behaviour-тесты с помощью cucumis
###

option '-l', '--log_level [LOG_LEVEL]', 'ALL, TRACE, DEBUG, INFO, WARN, ERROR, FATAL, OFF'
option '-t', '--test [TYPE]', "Test type is 'default', 'minimal' or 'junit'"
option null, '--test-name [String]', "Specify folder to test"

task 'test', 'Test the app', (options) ->
    # unit tests, jshint, etc.
    cmd(fs.rmr, ["#{root}/lib/tests"])
    cmd fs.mkdirp, ["#{root}/lib/tests", 0755]

    cmd (callback) ->
        # Запускатель тестов
        TestRunner = require('./src/tests/runner.coffee').TestRunner
        runner = new TestRunner(options.test, options.log_level || "")
        test_path = if options["test-name"] then options["test-name"] else null
        runner.consoleRun(test_path, callback)
    cmd_exit_soon()

task 'test-cucumis', 'Test certain features with cucumis (.feature files)', (options) ->
    invoke 'build-server'
    invoke 'build-sharejs'
    invoke 'build-tests'
    cmd (callback) ->
        testFolder = "./lib/tests/share/features/"
        runTest = (folder) ->
            cmd("#{bin}cucumis #{testFolder}#{folder}", [], handleOutput)

        folders = []
        if options['test-name']
            runTest(options['test-name'])
        else
            fs.readdir testFolder, (err, files) ->
                throw err if err
                runTest(file) for file in files
        callback()

###
Команды для работы с design-документами в couchDB
Все design-документы должны находиться в папке "src/server/couch/"
Design-документы должны быть написаны на javascript
Для работы с design-документами используется https://github.com/mikeal/node.couchapp.js
    couch-push -f [FILENAME]
        Отправляет указанный design-документ в БД

    couch-push-all
        Отправляет все design-документы в БД
###

option '-f', '--filename [FILENAME]', 'File with design doc to push, should be in src/server/couch folder'

_couchPushDoc = (q, filename, designsDir, dburl) ->
    filename = "#{designsDir}#{filename}"
    command = "#{bin}couchapp push #{filename} #{dburl}"
    q.cmd(command, handleOutput)

option '', '--dbconfname [dbconfname]', 'names of db in config, separated by comma, default is "main,operations"'

task 'couch-create', 'If not exists create empty database in couch', (options) ->
    dbConfNames = options.dbconfname or 'main,operations'
    dbConfNames = dbConfNames.split(',')
    request = require('request')
    tasks = []
    for dbconfname in dbConfNames
        do(dbconfname) ->
            dburl = Conf.getDbUrl(dbconfname)
            cmd request.put, [dburl], (err, result) ->
                if err
                    handleError(err)
                    throw err
                print result.body

task 'couch-push', 'Push design doc to couch', (options) ->
    throw "You should provide --filename option" unless options.filename
    dbconfname = options.dbconfname || 'main'
    designsDir = "#{root}" + Conf.getDbConf(dbconfname).designsDir
    dburl = Conf.getDbUrl(dbconfname)
    invoke 'couch-create'
    _couchPushDoc(cmd_queue, options.filename, designsDir, dburl)

task 'couch-push-all', 'Push all design docs to couch', (options) ->
    invoke 'couch-create'

    dbConfNames = options.dbconfname or 'main,operations'
    dbConfNames = dbConfNames.split(',')
    for dbconfname in dbConfNames
        do(dbconfname) ->
            # Ищем все файлы в директории, создаем и выполняем очередь для push
            designsDir = "#{root}" + Conf.getDbConf(dbconfname).designsDir
            dburl = Conf.getDbUrl(dbconfname)
            cmd (callback) ->
                badFiles = '.svn': null
                processFiles = (err, files) ->
                    return handleError(err) if err
                    goodFiles = []
                    for file in files
                        goodFiles.push(file) if file not of badFiles
                    console.log 'Found these design docs:\n', goodFiles.join(', ')

                    q = new CmdQueue(">> ", callback)
                    _couchPushDoc(q, filename, designsDir, dburl) for filename in goodFiles
                    q.start(10)
                fs.readdir(designsDir, processFiles)

###
Генерация индексной xml для sphinx
###

task 'generate-search-scheme', 'Generate and print search scheme', ->
    cmd (callback) ->
        IndexSourceGenerator = require('./src/server/search/indexer/index_source_generator').IndexSourceGenerator
        scheme = IndexSourceGenerator.getScheme()
        fs.writeFileSync("#{root}/bin/search_scheme.xml", scheme)
        callback()

task 'generate-search-index', 'Generate and print search index xml', (options) ->
    env = process.env
    indexType = env.INDEX_TYPE
    process.exit(0) if indexType == 'empty'
    IndexSourceGenerator = require('./src/server/search/indexer/index_source_generator').IndexSourceGenerator
    IndexSourceGenerator.outDeltaIndexSource(() ->
        #чтобы выходил при включенном кеше
        process.exit(0)
    )

task 'make-full-indexer-sphinx-conf', ' for full reindexing', (options) ->
    confDirPath = "#{root}/lib/etc/sphinxsearch"
    cmd fs.mkdirp, [ confDirPath ] if not fs.existsSync(confDirPath)
    cmd (callback) ->
        context = { pathToProject: root }
        content = Conf.getTemplate().compileFile("./search/indexer/full/full-indexing.conf").render(context)
        fs.writeFileSync("#{confDirPath}/full-indexing.conf", content)


task 'generate-full-search-index', 'Generate and print search index xml for full reindexing', (options) ->
    env = process.env
    indexType = env.INDEX_TYPE
    process.exit(0) if indexType == 'empty'
    FullIndexSourceGenerator = require('./src/server/search/indexer/full/index_source_generator').FullIndexSourceGenerator
    FullIndexSourceGenerator.outDeltaIndexSource(() ->
        #чтобы выходил при включенном кеше
        process.exit(0)
    )

task 'run-full-indexer', 'Run full reindexing process', () ->
    FullIndexer = require('./src/server/search/indexer/full').FullIndexer
    FullIndexer.run(() ->
        #чтобы выходил при включенном кеше
        process.exit(0)
    )

task 'build-version', 'Get version of build and write in src/server/version.coffee', ->
    cmd "LC_ALL=C svn info \"#{root}\"", (err, data) ->
        return console.error "[build-version] svn info has failed: #{err}" if err
        d =
            version: null
            branch: null
            deployTime: new Date

        try
            d.version = data.match(/Revision: (\d+)/)[1] # Rev number
            d.branch = data.match(/URL: .+\/([^\/\n]+)\/?/)[1] # URL dirname
        catch err
            console.error "[build-version] svn info output parsing has failed: #{err}, #{data}"

        try
            fs.writeFileSync("#{root}/src/server/version.coffee", "module.exports = #{JSON.stringify(d)};")
        catch err
            return console.error "[build-version] Writing version to file has failed: #{data}, #{err}"

###
Генерим sitemap
###
task 'generate-sitemap', 'Generate sitemap', ->
    cmd (callback) ->
        Sitemap = require('./src/server/sitemap').Sitemap
        Sitemap.generate(callback)
    cmd_exit_soon()
