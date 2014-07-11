fs = require('fs')

class FindTests
    walk = (dir, done) ->
        process.chdir('/');
        reg_tfile = /test_(\w*)+(.coffee|.js)$/
        results = []
        fs.readdir(dir, (err, list) ->
            if err 
                return done(err)
            i = 0
            next = (i) ->
                file = list[i]
                if !file 
                    return done(null, results)
                file = dir + '/' + file
                fs.stat(file, (err, stat) ->
                    if (stat && stat.isDirectory()) 
                        walk(file, (err, res) ->
                            results = results.concat(res)
                            next(++i)
                        )
                    else
                        if reg_tfile.test(file)
                            results.push(file)
                        next(++i)
                ) 
            next(0)
        )
        
module.exports.FindTests = FindTests

###
reporter = require('./objectreporter.coffee')

walk(__dirname + "/../../tests", (err, results) ->
    if err
        throw err
    #console.log(results)
    reporter.run(results)
)
###