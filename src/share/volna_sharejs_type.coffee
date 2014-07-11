###
Класс sharejs-операций, объединяющий JSON и formatted text.
Документом этого класса является JSON-объект с полем content.
В поле content содержится объект formatted text'а, остальные поля могут 
редактироваться json-операциями.
Операции форматирования текста применяются к полю content, все остальные
применяются как есть ко всему snapshot'у. При применении не проверяется, чтобы
json-операции не изменяли content.
Соответственно, трансформации между json и formatted text операциями не
производятся, т.к. они не могут влиять друг на друга.
###

clone = (o) -> JSON.parse(JSON.stringify o)

if WEB?
    jsonType = exports.types.json
    FText = exports.types.ftext
else
    jsonType = require('share/lib/types/json')
    FText = require('./formatted_text')

class VolnaType
    name: 'volna'
    
    create: -> {content: FText.create()}
    
    apply: (snapshot, ops) ->
        try
            snapshot = clone snapshot
        catch e
            console.warn "Got unclonable snapshot when applying 'volna' ops:", snapshot
            throw e
        for op in ops
            snapshot = @applyOp(snapshot, op)
        snapshot

    applyOp: (snapshot, op) ->
        if FText.isFormattedTextOperation(op)
            snapshot.content = FText.applyOp(snapshot.content, op)
        else
            snapshot = jsonType.apply(snapshot, [op])
        snapshot

    transformOp: (dest, op1, op2, type) =>
        is1 = FText.isFormattedTextOperation(op1)
        is2 = FText.isFormattedTextOperation(op2)
        return FText.transformOp(dest, op1, op2, type) if is1 and is2
        if (!is1 and !is2)
            dest[dest.length...] = jsonType.transform([op1], [op2], type)
            return dest
        try
            dest.push clone op1
        catch e
            console.warn "Got unclonable operation when transforming 'volna' ops:", op1
            throw e
        dest

    compose: (ops1, ops2) ->
        ###
        Объединяет несколько операций
        @param ops1: [OT operation]
        @param ops2: [OT operation]
        ###
        jsonType.compose(ops1, ops2)

volna = new VolnaType()
check = ->
if WEB?
    exports.types ||= {}
    exports._bt(volna, volna.transformOp, check, (dest, c) -> dest.push c)
    exports.types.volna = volna
else
    require('share/lib/types/helpers').bootstrapTransform(volna, volna.transformOp, check, (dest, c) -> dest.push c)
    module.exports = volna
