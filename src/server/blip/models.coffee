_ = require('underscore')
Model = require('../common/model').Model
BlipSearchConverter = require('./search_converter').BlipSearchConverter
DateUtils = require('../utils/date_utils').DateUtils
Ptag = require('../ptag').Ptag
BlipExportMarkupBuilder = require('../export/blip').BlipExportMarkupBuilder

MAX_SNIPPET_LENGTH = 100
TEXT_TYPE = 'TEXT'
TEXT_ATTR = 't'
LINE_TYPE = 'LINE'

#Список плагинов блипа.
PLUGIN_LIST = [
    require('../message/model').MessageModel
    require('../gtag/model').GTagModel
    require('../task/model').TaskModel
    require('../gadget/model').GadgetModel
]

ACTIONS = require('../wave/constants').ACTIONS

INLINE_INSERTATION = require('./constants').INLINE_INSERTATION
INLINE_DELETION = require('./constants').INLINE_DELETION

{PLUGIN_CHANGING_STATES_NOT_MY, PLUGIN_CHANGING_STATES_CHANGE} = require('./constants')

class BlipModel extends Model
    ###
    Класс, представляющий базовую модель блипа.
    ###
    constructor: (@id=null, @_rev=undefined, @waveId=null, @content=[], @isRootBlip=null, @contributors=[], @readers={}, @contentTimestamp=DateUtils.getCurrentTimestamp(), @removed=yes, @version=0, @isFoldedByDefault=no, @_wave=null, @pluginData = {}, @contentVersion=0) ->
        super('blip')
        #надо уведомить пользователей о новом комментарии
        @needNotificate = false
        # массив пользователей которых оповестили о чем либо в этом блипе (меншен, таск или просто коммент)
        # {random1: userid1, random2: userid2}
        @notificationRecipients = {}
        @_attachedPlugins = []
        @_isContainer = false
        for PluginClass in PLUGIN_LIST
            @_attach(PluginClass)


    _attach: (PluginClass) =>
        ###
        Добавляет плагин к блипу.
        @param: PluginClass: PluginModel
        ###
        plugin = new PluginClass(@)
        @_attachedPlugins.push(plugin)
        @[plugin.getName()] = plugin

    getText: (start, end, lineDelimiter=' ') ->
        ###
        Возвращает текст блипа с учетом текста плагинов.
        @param start: int - номер строки блипа с которой начинаем
        @param end: int - заканчиваем
        @returns: string
        ###
        params = {}
        pluginParams = @_pluginMap((plugin) =>
            return plugin.getTextParams()
        )
        params = _.extend(params, pluginParams...)
        return @_getText(start, end, params, lineDelimiter)

    getPureText: () ->
        ###
        Возвращает текст блипа без текста плагинов.
        @returns: string
        ###
        @_getText(null, null)

    getTitle: () ->
        ###
        Возвращает заголовок блипа (первое предложение или строку).
        @returns: string
        ###
        return @getText(0, 1)

    getSnippet: () ->
        ###
        Возвращаем дайджест блипа (часть содержимого).
        @returns: string
        ###
        return @getText(1)[0..MAX_SNIPPET_LENGTH]

    getTypedContentBlocksParam: (blockType, paramName) ->
        params = []
        @iterateBlocks((type, block) ->
            return if blockType != type
            param = block.params?[paramName]
            return if not param
            params.push(param)
        )
        return params

    hasContributor: (user) ->
        ###
        Проверяет, есть ли в блипе редактор с переданным id.
        @param id: string
        @returns: bool
        ###
        for contributor in @contributors
            return true if user.isEqual(contributor.id)
        return false

    getReadState: (user) ->
        for own id, version of @readers
            isEqual = if _.isString(user) then user == id else user.isEqual(id)
            return true if isEqual and version == @contentVersion
        return false

    setWave: (wave) ->
        ###
        Сохраняет ссылку на волну в котороый находится блип.
        @param wave: WaveModel
        ###
        @_wave = wave

    getWave: () ->
        ###
        Возвращает ссылку на волну в которо йнаходится блип.
        @returns: WaveModel
        ###
        return @_wave

    getAuthorId: () ->
        return @contributors[0]?.id

    checkPermission: (user, action) ->
        return @getWave().checkPermission(user, action)

    checkOpPermission: (ordinarOps, inlineOps, user, childBlips) ->
        ###
        Проверяет имеет ли пользователь запрошенный доступ к блипу.
        @param useer: UserModel
        @accessType: int
        @returns: bool
        ###
        actions = []
        if user.isEqual(@getAuthorId())
            actions.push(ACTIONS.ACTION_WRITE_SELF_DOCUMENT)
            return [@checkPermission(user, actions), actions]
        if not _.isEmpty(inlineOps)
            for own id, operationType of inlineOps
                if operationType == INLINE_INSERTATION
                    actions.push(ACTIONS.ACTION_COMMENT)
                    continue
                if operationType == INLINE_DELETION
                    childBlip = childBlips[id]
                    if not childBlip
                        actions.push(ACTIONS.ACTION_WRITE)
                        console.error("Bugcheck. Attempt to delete unknown blip #{id} from #{@id}")
                        continue
                    actions.push(if user.isEqual(childBlip.getAuthorId()) then ACTIONS.ACTION_COMMENT else ACTIONS.ACTION_WRITE)
        for op in ordinarOps
            if _.any(@_pluginMap((plugin) -> plugin.checkOpPermission(op, user)))
                 actions.push(ACTIONS.ACTION_PLUGIN_ACCESS)
                 continue
            if op.p?[0] == 'isFoldedByDefault'
                actions.push(ACTIONS.ACTION_SET_DEFAULT_FOLDING)
                continue
            actions.push(ACTIONS.ACTION_WRITE)
        return [@checkPermission(user, actions), actions]

    getAnswerInsertionOp: (answerBlipId, enquiryBlipId) ->
        ###
        Создает операцию вставки ответа к другому блипу.
        @params answerBlipId: id блипа ответа
        @params enquiryBlipId: id блипа на который отвечаем
        @returns: array
        ###
        op = {}
        op['ti'] = ' '
        op.params =
            "__TYPE": "BLIP"
            "__ID": answerBlipId
            "RANDOM": Math.random()
        @iterateBlocks((blockType, block, position) ->
            return if blockType != 'BLIP'
            if block.params.__ID == enquiryBlipId
                op.p = position + block.t.length
                op.params.__THREAD_ID = block.params.__THREAD_ID or enquiryBlipId
                op.params.shiftLeft = true
        )
        return null if not op.p
        return [op]

    splitOps: (ops) ->
        ordinarOps = []
        inlineOps = {}
        EMPTY_INLINE_OP = INLINE_INSERTATION | INLINE_DELETION
        for op in ops
            inlineOperationType = @isInlineProcessingOp(op)
            if not inlineOperationType
                ordinarOps.push(op)
                continue
            id = op.params.__ID
            inlineOps[id] |= inlineOperationType
            delete inlineOps[id] if inlineOps[id] ==  EMPTY_INLINE_OP
        return [ordinarOps, inlineOps]

    isInlineProcessingOp: (op) ->
        return if op.params?.__TYPE != 'BLIP'
        return INLINE_INSERTATION if op.ti
        return INLINE_DELETION if op.td
        return

    @getSearchIndexHeader: () ->
        ###
        Возвращает список индексируемых полей для заголовка поискового индекса.
        Поля собираются у блипа и всех плагинов.
        @returns: array
        ###
        fields = [
            {elementName: 'field', name: 'title'}
            {elementName: 'field', name: 'content'}
            {elementName: 'attr', name: 'blip_id', type: 'string'}
            {elementName: 'attr', name: 'wave_id', type: 'string'}
            {elementName: 'attr', name: 'wave_url', type: 'string'}
            {elementName: 'attr', name: 'changed', type: 'timestamp'}
            {elementName: 'attr', name: 'content_timestamp', type: 'timestamp'}
            {elementName: 'attr', name: 'ptags', type: 'multi'}
            {elementName: 'attr', name: 'shared_state', type: 'int', bits: 8}
        ]
        pluginFields = @_pluginMap((Plugin) ->
            return Plugin.getSearchIndexHeader()
        )
        return BlipSearchConverter.fromFieldsToIndexHeader(fields.concat(pluginFields...))

    getSearchIndex: () ->
        ###
        Возвращает список индексируемых полей для поискового индекса.
        Поля собираются у блипа и всех плагинов.
        @returns: array
        ###
        ptagIds = []
        wave = @getWave()
        participants = wave.getParticipantsWithRole(true)
        if participants
            for participant in participants
                continue if not participant.ptags
                for ptagId in participant.ptags
                    searchPtagId = Ptag.getSearchPtagId(participant.id, ptagId)
                    ptagIds.push(searchPtagId) if searchPtagId?
        fields = [
            {name: 'title', value: @getTitle()}
            {name: 'content', value: @getPureText()}
            {name: 'blip_id', value: @id}
            {name: 'wave_id', value: @waveId}
            {name: 'wave_url', value: wave.getUrl()}
            {name: 'changed', value: Math.max(wave.contentTimestamp, @contentTimestamp)}
            {name: 'content_timestamp', value: @contentTimestamp}
            {name: 'ptags', value: ptagIds.join(' ')}
            {name: 'shared_state', value: wave.getSharedState()}
        ]
        pluginFields = @_pluginMap((plugin) =>
            return plugin.getSearchIndex()
        )
        return BlipSearchConverter.fromFieldsToIndex(@getOriginalId(), fields.concat(pluginFields...))

    markAsChanged: (changes, ops, userId) ->
        super(changes, ['content', 'removed', 'pluginData'], () =>
            @_setTimestampToNow()
            @_updateContentVersionAccordingPluginsChangingSate(changes, ops)
            @markAsRead(userId) if userId
        )

    _updateContentVersionAccordingPluginsChangingSate: (changes, ops) ->
        ###
        @param ops: array
        Увеличивает contentVersion (вллияет на прочитанность), если контент блипа поменялся, учитывая, поменялись ли плагины
        ###
        return if _.contains(changes, 'removed')
        pluginChangingState = @_pluginMap((plugin) -> return plugin.getChangingState(ops)) #массив состояний измененности для всех плагинов
        reduceIterator = (memo, state) -> return memo | state
        reducedPluginChangingState = _.reduce(pluginChangingState, reduceIterator, 0) #суммируем, в результате получится целое число - сумма констант, по одной на операцию со сдвигом вправо на 2 разряда.
        stateVector = []
        for op in ops
            state = reducedPluginChangingState & 3 #получаем состояние для очередной операции (3 = 0b11)
            reducedPluginChangingState >>= 2
            stateVector.push(state)
        checkNotMyState = (stateVector) -> #все операции мимо плагинов, значит поменялся контент блипа
            return _.all(stateVector, (state) -> return state == PLUGIN_CHANGING_STATES_NOT_MY)
        checkChangeState = (stateVector) -> #поменялся один из плагинов
            return _.any(stateVector, (state) -> return state >= PLUGIN_CHANGING_STATES_CHANGE)
        @_updateContentVersion() if checkNotMyState(stateVector) or checkChangeState(stateVector)

    markAsRead: (readerId) ->
        return false if @readers[readerId] == @contentVersion
        @readers[readerId] = @contentVersion
        return true

    iterateBlocks: (iterator) ->
        ###
        Итератор по контенту блипа.
        @param iterator: function
            blockType: string - тип блока
            block: object - сам блок
        ###
        return if not @content or not _.isArray(@content)
        position = 0
        for block in @content
            blockType = block.params?.__TYPE
            iterator(blockType, block, position)
            position += block.t.length if block.t and block.t.length

    hasBlockTypes: (blockTypes) ->
        ###
        Проверяет есть ли в контенте хотя бы один из перечисленных типов блоков
        используется в коммент нотификаторе для проверки меншенов и тасков
        ###
        for block in @content
            blockType = block.params?.__TYPE
            return true if blockType in blockTypes
        return false

    getChildIds: () ->
        ids = []
        @iterateBlocks((blockType, block) ->
            return if blockType != 'BLIP' or not block.params
            id = block.params.__ID
            return if not id
            ids.push(id)
        )
        return ids

    getFileIds: ->
        ids = []
        @iterateBlocks((blockType, block) ->
            return if blockType != 'FILE' or not block.params
            id = block.params.__ID
            return if not id
            ids.push(id)
        )
        return ids

    _getText: (start, end, params, lineDelimiter=' ') ->
        ###
        Возвращает содержимое блипа.
        Переводы строк обозначаются пробелами.
        @param start: int - номер строки блипа с которой начинаем
        @param end: int - заканчиваем
        @params: object
            type: string - ключ, тип блока
                attr: название атрибута блока, содержащего текст
                decorator: function(string): string - декратор текста
        @returns: string
        ###
        lines = @_getTextByLines(params)
        linesWithText = (line.trim() for line in lines when line.trim().length)
        linesWithText = linesWithText[start...end] if start or end
        return linesWithText.join(lineDelimiter)

    _updateContentVersion: () ->
        ###
        Будет вызван при изменении полей, влияющих на содержимое блипа.
        ###
        @contentVersion = @version

    @_pluginMap: (iterator) ->
        ###
        @see: _pluginMap
        ###
        result = []
        for Plugin in PLUGIN_LIST
            result.push(iterator(Plugin))
        return result

    _pluginMap: (iterator) ->
        ###
        Мап-функция. Итерируется по всем плагинам применяя iterator к каждому плагину.
        Результаты работы iterator попадают в результат.
        @param iterator: function
        @returns array
        ###
        result = []
        for plugin in @_attachedPlugins
            result.push(iterator(plugin))
        return result

    _getTextByLines: (params={}) ->
        ###
        Возвращает массив строк содержимого блипа.
        Всегда добавляет в результат текстовое содержимое текста. В качестве декотарора поумолчанию спользуется f(x) = x
        @see: _getText
        @params: object
        @return: array
        ###
        params[TEXT_TYPE] = {}
        lines = []
        currentLine = []
        add = () ->
            lines.push(currentLine.join('')) if currentLine.length
            currentLine = []
        @iterateBlocks((type, block) ->
            return add() if type == LINE_TYPE
            return currentLine.push(' ') if type not of params
            param = params[type]
            if not param.attr
                attrValue = block[TEXT_ATTR]
            else
                attrValue = block.params?[param.attr]
            decorator = param.decorator or _.identity
            blockText = if attrValue then decorator(attrValue) else ' '
            currentLine.push(blockText)
        )
        add()
        return lines

    getExportMarkup: ->
        builder = new BlipExportMarkupBuilder(@id, @contentTimestamp, @getAuthorId())
        @iterateBlocks(builder.handleBlock)
        return builder.build()

module.exports.BlipModel = BlipModel
