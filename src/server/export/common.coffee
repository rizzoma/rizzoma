class ExportMarkupNode

    constructor: (@type, attrs) ->
        for key, value of attrs
            @[key] = value

exports.ExportMarkupNode = ExportMarkupNode
