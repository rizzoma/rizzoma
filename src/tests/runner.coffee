fs = require 'fs-plus'
nodeunit = require 'nodeunit'
child_process = require 'child_process'
url = require 'url'
path = require 'path'
_ = require 'underscore'

class TestRunner
    constructor: (reporter_type = 'default', @log_level) ->
        ###
        @reporter_type: string
        ###
        @reporter_type = reporter_type
        @root_path = path.resolve(__dirname + "/../..")
        @test_path = './src/tests'
        @junit_path = @rootDir() + '/lib/tests'

    @stripFilenames: (files, stripped_str) ->
        ###
        @files: array of string
        @stripped_str: string
        Обрезаем строку stripped_str у каждого элемента files
        ###
        new_files = []
        for file in files
            new_files.push {
                short_name: file.replace(stripped_str, ''),
                name: file,
            }
        return new_files
    
    getFiles: (test_path, callback) ->
        ###
        @test_path: string
        @callback: function
        Получаем пути к файлам тестов и возвращаем их в callback
        ###
        files = []
        find = fs.find(test_path)
        find.on('file', (file, stat) =>
            if /\/test_[^\/]+\.coffee$/.test(file)
                files.push file
        )
        find.on('end', () =>
            return callback(null, files);
        )

    consoleRun: (test_path=null, callback) =>
        ###
        @test_path: string
        Запускалка тестов из косоли
        ###
        test_path = @test_path if not test_path
        @getFiles(test_path, (except, files) =>
            @reporterRun(files, (except, result_string) =>
                console.log result_string
                callback(except)
            )
        )
        
    rootDir: ->
        return path.resolve(__dirname + "/../..")
    
    reporterRun: (test_list, callback) ->
        ###
        @test_list: array of string
        @callback: function
        Запускалка тестов, запускаем в дочернем процессе,
        чтобы иметь возможность читать поток родителя stdout,
        в callback отдаем результаты тестов
        ###
        if @reporter_type == 'junit'
            test_list.unshift @rootDir() + '/lib/tests'
            test_list.unshift '--output'
            
        test_list.unshift @reporter_type
        test_list.unshift '--reporter'
        
        new_env = _.clone(process.env)
        new_env.LOG_LEVEL = @log_level
        test = child_process.spawn(@rootDir() + "/node_modules/.bin/nodeunit", test_list,
                {
                    cwd: undefined,
                    env: new_env,
                    customFds: [-1, -1, -1]
                })
        test.stdout.setEncoding('utf8')
        test.stderr.setEncoding('utf8')
        result_string = ''
        test.stdout.on('data', (data) => result_string += data)
        test.stderr.on('data', (data) => result_string += data)
        test.on('exit', (code) => return callback(null, result_string))
     
     webTestHandler: (req, callback) ->
        ###
        @req: object request
        @callback: function
        Обрабатываем request и отдаем параметры в шаблон
        ###
        submitted_files = []
        submit = false
        if req.query.submit isnt undefined
            delete req.query.submit
            submit = true
        
        for k,v of req.query
            submitted_files.push k
        
        @getFiles(@test_path, (except, files) => 
            files = TestRunner.stripFilenames(files, @test_path)
            exec_test_files = []
            if submitted_files.length > 0
                for file in files
                    if file.name in submitted_files
                        exec_test_files.push(file.name)
                        file.on = true
            if submit
                @reporterRun(exec_test_files, (except, result_string) ->
                    params = {
                        result_string: result_string,
                        link: url.format({query: req.query}),
                    }
                    return callback(null, params)
                )
            else
                params = {files: files, }
                return callback(null, params)
        )
            
exports.TestRunner = TestRunner