BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
{addExportTask, findArchives} = require('./multi')

class ExportModule extends BaseModule

    constructor: (args...) ->
        super(args..., Response)

    findArchives: (request, args, callback) ->
        findArchives(request.user.id, callback)
    @::v('findArchives', [])

    exportTopics: (request, args, callback) ->
        addExportTask(request.user.id, args.ids, callback)
    @::v('exportTopics', ['ids'])

exports.ExportModule = ExportModule
