Conf = require('../conf').Conf

reportTemplate = Conf.getTemplate().compileFile('test_report.html')
reportView = (req, res) ->
    params =
        everyauth: req.user
        loggedIn: req.loggedIn
        sessionId: req.sessionID

    TestRunner = require('./test_runner').TestRunner
    testRunner = new TestRunner
    testRunner.searchTestFiles '.'

    testFiles = []
    rootDir = __dirname.replace 'src/server/test', ''
    for key of req.query
        if req.query[key] == 'on'
            testFiles.push key.replace rootDir, ''

    testToRun = []
    for test in testRunner.testFiles
        toRun = file: test
        if test in testFiles
            toRun['is_run'] = true
        testToRun.push toRun
    params['tests'] = testToRun

    if testFiles.length > 0
        testRunner.testFiles = testFiles

        testRunner.runTests 'html', false, (error, stdout, stderr)->
            try
                res.send reportTemplate.render({'stdout': stdout, 'stderr': stderr, })
            catch e
                Conf.getLogger('http').error(e)
                res.send 500
    else
        try
            res.send reportTemplate.render(params)
        catch e
            Conf.getLogger('http').error(e)
            res.send 500

module.exports.reportView = reportView