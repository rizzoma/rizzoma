{ModelField, ParamsField, ModelType} = require('../editor/model')

getElement = exports.getElement = (name, properties) ->
    res = document.createElementNS('http://www.w3.org/2000/svg', name)
    if properties?
        for key, value of properties
            res.setAttribute(key, value)
    return res

copy = exports.copy = (object) ->
    JSON.parse(JSON.stringify(object))

exports.copyNodeTextContent = (element) ->
    ###
    Копирует содержимое HTML-ноды, пропуская треды
    ###
    res = element.cloneNode(false)
    if res.nodeName is 'INPUT'
        res.disabled = 'disabled'
    for child in element.childNodes
        continue if $(child).hasClass('blip-thread')
        res.appendChild(copyNodeTextContent(child))
    return res

exports.getBlockType = (block) ->
    block[ModelField.PARAMS][ParamsField.TYPE]

getNodeClass = (node) ->
    node.getAttribute('class') || ''

hasClass = exports.hasClass = (node, value) ->
    " #{getNodeClass(node)} ".indexOf(" #{value} ") > -1

exports.addClass = (node, value) ->
    return if hasClass(node, value)
    node.setAttribute('class', "#{getNodeClass(node)} #{value}".trim())

exports.removeClass = (node, value) ->
    className = (" #{getNodeClass(node)} ").replace(" #{value} ", ' ').trim()
    node.setAttribute('class', className)

exports.removeClasses = (node, values) ->
    removeClassNames = values.join('|')
    className = (" #{getNodeClass(node)} ").replace(new RegExp(" (?:#{removeClassNames}) "), ' ').trim()
    node.setAttribute('class', className)

convertTextOpToSnapshot = (op) ->
    if 'ti' not of op
        throw "Cannot convert text operation #{JSON.stringify(op)} to snapshot"
    res = {}
    res[ModelField.TEXT] = op.ti
    res[ModelField.PARAMS] = copy(op[ModelField.PARAMS])
    return res

convertTextOpsToSnapshot = exports.convertTextOpsToSnapshot = (ops) ->
    (convertTextOpToSnapshot(op) for op in ops)

convertBlipOpToSnapshot = (op) ->
    if 'ops' not of op
        throw "Cannot convert blip operation #{JSON.stringify(op)} to snapshot"
    return convertTextOpsToSnapshot(op.ops)

exports.convertBlipOpsToSnapshot = (ops) ->
    (convertBlipOpToSnapshot(op) for op in ops)

exports.convertTextOpsToBlipOps = (ops) ->
        params = {}
        params[ParamsField.TYPE] = ModelType.BLIP
        return [{ti: ' ', params, ops, blipParams: {}}]
