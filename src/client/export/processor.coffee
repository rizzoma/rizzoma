BaseRouter = require('../../share/base_router').BaseRouter
Request = require('../../share/communication').Request

class ExportProcessor extends BaseRouter

    findArchives: (callback) ->
        request = new Request({}, callback)
        @_rootRouter.handle('network.export.findArchives', request)
        
    exportTopics: (ids, callback) ->
        request = new Request({ids: ids}, callback)
        @_rootRouter.handle('network.export.exportTopics', request)

exports.ExportProcessor = ExportProcessor
