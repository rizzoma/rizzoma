BaseModule = require('../../share/base_module').BaseModule
FileProcessor = require('./processor').FileProcessor
ck = window.CoffeeKup

class FileModule extends BaseModule
    constructor: (args...) ->
        super args...
        @_fileProcessor = new FileProcessor(@_rootRouter)

exports.FileModule = FileModule