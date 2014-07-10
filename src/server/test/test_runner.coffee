fs = require 'fs'
sys = require 'util'
child_process = require 'child_process'

class TestRunner
    constructor: ->
        @testFiles = []

    searchTestFiles: (path = '.') ->
        files = fs.readdirSync path

        if not files
            return

        for file in files
            fullPath = "#{path}/#{file}"
            stats = fs.statSync fullPath

            if not stats
                continue
            if stats.isFile() and file.match('^test_[a-zA-Z0-9_]*\.coffee$')
                @testFiles.push fullPath
            if stats.isDirectory()
                @searchTestFiles fullPath

    runTests: (reportFormat = 'default', logOnConsole = false, callback) ->
        switch reportFormat
            # TODO: Брать имена шаблонов репортера из каталога
            when 'html' then nodeunit = require('nodeunit').reporters.html
            when 'junit' then nodeunit = require('nodeunit').reporters.junit
            when 'minimal' then nodeunit = require('nodeunit').reporters.minimal
            when 'default' then nodeunit = require('nodeunit').reporters.default
            else
                console.log 'This format {#reportFormat} type is not supported...'
                return

        stdout_data = ''
        stderr_data = ''
        @testFiles.unshift '--reporter', reportFormat
        runner = child_process.spawn 'nodeunit', @testFiles

        runner.stderr.setEncoding 'utf8'
        runner.stderr.on('data', (data) =>
            stderr_data += data
            if logOnConsole
                sys.puts data
        )
        runner.stdout.setEncoding 'utf8'
        runner.stdout.on('data', (data) =>
            stdout_data += data
            if logOnConsole
                sys.puts data
        )

        runner.on('exit', (code) =>
            callback(null, stdout_data, stderr_data)
        )

module.exports.TestRunner = TestRunner

#runner = new TestRunner
#runner.searchTestFiles '.'
#runner.runTests 'default'