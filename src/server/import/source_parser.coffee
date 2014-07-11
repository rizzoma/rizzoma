async = require('async')
_ = require('underscore')
WaveModel = require('../wave/models').WaveModel
BlipModel = require('../blip/models').BlipModel
waveCts = require('../wave/constants')
WaveGenerator = require('../wave/generator').WaveGenerator
BlipGenerator = require('../blip/generator').BlipGenerator
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
DateUtils = require('../utils/date_utils').DateUtils

WAVE_TITLE_LENGTH = 62

LINK_REDIRECT_PREFIX = '/r/gw/'

CREATION_REASON_IMPORT = require('../user/constants').CREATION_REASON_IMPORT

class ImportSourceParser
    constructor: () ->
    
    sourceToObject: (waveData) ->
        return JSON.parse(waveData)

    parse: (waveId, source, blipIds, callback) ->
        ###
        Парсит гугловый документ одной волны
        ###
        sourceObj = @sourceToObject(source)
        tasks = [
            async.apply(@_parseWave, waveId, sourceObj)
            (wave, callback) =>
                @_parseBlips(sourceObj, wave, blipIds, (err, blips) ->
                    callback(err, wave, blips)
                )
            (wave, blips, callback) ->
                for blip in blips
                    if blip.isRootBlip
                        wave.rootBlipId = blip.id
                        break
                callback(null, wave, blips)
        ]
        async.waterfall(tasks, callback)
        
    getWaveTitle: (source) ->
        ###
        Возвращает заголовок волны
        используется при показе статистики
        ###
        sourceObj = @sourceToObject(source)
        sourceData = sourceObj[0].data
        blipsData = sourceData.blips
        for bId, blipData of blipsData
            if(@_isRootBlip(blipData, sourceData.waveletData.rootThread))
                lastIndex = blipData.content.substr(1).indexOf("\n")
                lastIndex = WAVE_TITLE_LENGTH if lastIndex == -1
                title = blipData.content.substring(0, lastIndex+1)
                if title.length > WAVE_TITLE_LENGTH
                    title = title.substr(0, WAVE_TITLE_LENGTH-2) + "…"
                if title.length and title[0] == "\n"
                   title = title.substr(1) 
                return title
        return null
    
    _parseWave: (waveId, sourceObj, callback) =>
        ###
        Заполняет данными модель волны
        ###
        tasks = [
            (callback) ->
                return callback(null, waveId) if waveId
                WaveGenerator.getNext(callback)
            (waveId, callback) =>
                waveletData = sourceObj[0].data.waveletData
                wave = new WaveModel()
                wave.id = waveId
                wave.sharedState = waveCts.WAVE_SHARED_STATE_PRIVATE
                #if  'public@a.gwave.com' in waveletData.participants
                #    wave.sharedState = waveCts.WAVE_SHARED_STATE_PUBLIC
                #60 * 5 + 5 минут чтобы попала в индексирование
                wave.contentTimestamp = DateUtils.getCurrentTimestamp() + 300
                @_parseWaveParticipants(waveletData, (err, participants) ->
                    return callback(err, null) if err
                    wave.participants = participants
                    callback(null, wave)
                )
        ]
        async.waterfall(tasks, callback)

    _normalizeEmail: (email) ->
        ###
        приводит волновые мыла к нашему формату
        ###
        return email.replace('@googlewave.com', '@gmail.com')
    
    _isEmailToSkip: (email) ->
        ###
        Проверяет нужно ли импортировать такой емэйл
        ###
        emailsToSkip = [
            'public@a.gwave.com'
            '@appspot.com'
            '@invite.gwave.com'
        ]
        for emailToSkip in emailsToSkip
            return true if email.indexOf(emailToSkip) != -1
        return false
    
    parseParticipantsEmailsAndRoles: (waveletData) ->
        ###
        Достает емэйлы и роли участников волны
        ###
        participantRoles = {}
        partcipantEmails = []
        for email, role of waveletData.participantRoles
            continue if @_isEmailToSkip(email)
            normalizedEmail = @_normalizeEmail(email)
            partcipantEmails.push(normalizedEmail)
            #if role == 'FULL'
            participantRoles[normalizedEmail] = waveCts.WAVE_ROLE_MODERATOR
            #else
            #    participantRoles[normalizedEmail] = waveCts.WAVE_ROLE_READER
        return {'partcipantEmails': partcipantEmails, 'participantRoles': participantRoles}
    
    _parseWaveParticipants: (waveletData, callback) ->
        ###
        Возвращает участников с нашими id, если участника нет в бд создает его
        ###
        res = @parseParticipantsEmailsAndRoles(waveletData)
        partcipantEmails = res.partcipantEmails
        participantRoles = res.participantRoles
        UserCouchProcessor.getOrCreateByEmails(partcipantEmails, CREATION_REASON_IMPORT, (err, users) ->
            return callback(err, null) if err
            participants = []
            for email, role of participantRoles
                participants.push({
                    id: users[email].id
                    role: role
                })
            callback(null, participants)
        )

    generateBlipIds: (waveId, blipsData, callback) =>
        ###
        генерит хеш id блипа из гула : наш id блипа
        ###
        idsCount = _.keys(blipsData).length
        BlipGenerator.getNextRange(waveId, idsCount, (err, ids) ->
            return callback(err, null) if err
            results = {}
            for externalId, value of blipsData
                results[externalId] = ids.pop()
            callback(null, results)
        )

    _parseBlips: (sourceObj, wave, blipIds, callback) ->
        @_wasElementBlipIds = {}
        sourceData = sourceObj[0].data
        tasks = [
            (callback) =>
                return callback(null, blipIds) if blipIds
                @generateBlipIds(wave.id, sourceData.blips, callback)
            (blipIds, callback) =>
                @_parseBlipsMap(wave, sourceData, blipIds, callback)
        ]
        async.waterfall(tasks, callback)
        
    _parseBlipsMap: (wave, sourceData, blipIds, callback) ->
        blipsTasks = []
        for bId, blipData of sourceData.blips
            blipsTasks.push(do(blipData) =>
                return async.apply(@_parseBlip, wave, blipData, sourceData, blipIds)
            )
        async.series(blipsTasks, callback)
    
    _parseBlip: (wave, blipData, sourceData, blipIds, callback) =>
        ###
        Заполняет модель блипа
        ###
        blip = new BlipModel()
        blip.id = blipIds[blipData.blipId]
        blip.waveId = wave.id
        blip.isRootBlip = @_isRootBlip(blipData, sourceData.waveletData.rootThread)
        blip.contentTimestamp = Math.round(blipData.lastModifiedTime / 1000)
        tasks = {
            content: (callback) =>
                content = @_parseBlipContent(blipData, blipIds, sourceData)
                callback(null, content)
            contributors: async.apply(@_parseBlipContributors, blipData)
        }
        async.series(tasks, (err, res) ->
            return callback(err, null) if err
            blip.content = res.content
            if res.contributors.length
                blip.contributors = res.contributors
            else
                blip.contributors = [wave.participants.length-1]
            # make all blips is read
            for p in wave.participants
                blip.readers[p.id] = blip.contentVersion
            callback(null, blip)
        )
        
    _isRootBlip: (blipData, rootThread) ->
        ###
        возвращает является ли блип корневым
        ###
        return blipData.parentBlipId is null and
            (not rootThread or 
                not rootThread.blipIds.length or 
                blipData.blipId == rootThread.blipIds[0])
    
    _parseBlipContributors: (blipData, callback) =>
        ###
        Возвращает контрибуторов блипа, если пользователя нет в БД создает его
        ###
        emails = []
        for email in blipData.contributors
            continue if @_isEmailToSkip(email)
            emails.push(@_normalizeEmail(email))
        UserCouchProcessor.getOrCreateByEmails(emails, CREATION_REASON_IMPORT, (err, users) ->
            return callback(err, null) if err
            contributors = []
            for email in emails
                contributors.push({ id: users[email].id })
            callback(null, contributors)
        )

    _parseBlipContent: (blipData, blipIds, sourceData) ->
        ###
        Парсит контент блипа
        ###
        content = @_getBlipContentFragments(blipData, blipIds, sourceData)
        replies = @_findBlipReplies(blipData, sourceData, blipIds)
        content = content.concat(replies)
        return content

        
    _getBlipContentFragments: (blipData, blipIds, sourceData) ->
        contentLength = blipData.content.length
        ranges = @_getSortedBlipContentRanges(blipData)
        rangesLength = ranges.length
        content = []
        for i in [0..rangesLength-1]
            startPos = ranges[i]
            endPos = if i+1 < rangesLength then ranges[i+1] else contentLength
            endPos--
            content.push(@_parseBlipContentRange(blipData, blipIds, startPos, endPos, sourceData.threads))
        return content
        
    _insertSortedElementIfNotInArray: (array, value) ->
        ###
        Вставляет элемент в нужное место сортированного массива
        @param array: Array - сортированный массив в который вставляем
        @param value: Number - значение
        ###
        if not _.include(array, value)
            index = _.sortedIndex(array, value)
            array.splice(index, 0, value)
    
    _fillElementsSortedRanges: (ranges, elements, lastContentPos) ->
        ###
        Заполняет массив границ фрагментов елементами блипа
        ###
        for sPos, sElement of elements
            sPos = parseInt(sPos)
            @_insertSortedElementIfNotInArray(ranges, sPos)
            if sPos < lastContentPos
                @_insertSortedElementIfNotInArray(ranges, sPos+1)
        
    _fillAnnotationsSortedRanges: (ranges, annotations, lastContentPos) ->
        ###
        Заполняет массив границ фрагментов елементами блипа
        ###
        for annotation in annotations
            @_insertSortedElementIfNotInArray(ranges, annotation.range.start)
            if annotation.range.end < lastContentPos
                @_insertSortedElementIfNotInArray(ranges, annotation.range.end + 1)
    
    _getSortedBlipContentRanges: (blipData) ->
        ###
        Строит массив границ начал фрагментов контента
        ###
        ranges = []
        lastContentPos = blipData.content.length - 1
        @_fillElementsSortedRanges(ranges, blipData.elements, lastContentPos)
        @_fillAnnotationsSortedRanges(ranges, blipData.annotations, lastContentPos)
        if ranges[0] != 0
            ranges.unshift(0)
        return ranges
    
    _parseBlipContentRange: (blipData, blipIds, startPos, endPos, threads) =>
        ###
        Парсит участок контента.
        Возвращает фрагмент со всеми аннотациями
        @param blipData: Object
        @param startPos: int
        @param endPos: int
        ###
        fragment =
            t: blipData.content.substring(startPos, endPos + 1).replace("\n", " ")
            params: {}
        element = blipData.elements[startPos]
        if element
            fragment.params = @_getElementParams(element, blipIds, threads)
        else
            fragment.params = @_getAnnotationsParams(blipData.annotations, startPos, endPos)
        return fragment

        
    _findBlipReplies: (blipData, sourceData, blipIds) ->
        ###
        находит ответы блипа
        ###
        replies = @_findBlipInnerReplies(blipData, blipIds)
        if blipData.parentBlipId and blipData.threadId != ""
            replies = replies.concat(@_findBlipThreadReplies(blipData, sourceData, blipIds))
        else if @_isRootBlip(blipData, sourceData.waveletData.rootThread)
            replies = replies.concat(@_findRootThreadReplies(blipData, sourceData, blipIds))
        return replies
        
    _findRootThreadReplies: (blipData, sourceData, blipIds) ->
        ###
        Находит все рутовые реплаи и возврщает их чз LINE
        если в рутовом треде больше чем один блип
        ###
        content = []
        rootThread = sourceData.waveletData.rootThread
        if not rootThread or not rootThread.blipIds or rootThread.blipIds.length < 2
            return content
        bIds = rootThread.blipIds
        bIds.shift()
        for bId in bIds
            blipId = blipIds[bId]
            if blipId
                content.push(@_createSimpleLineFragment())
                content.push(@_createInlineBlipFragment(blipId))
        return content
    
    _createInlineBlipFragment: (blipId) ->
        ###
        Создает фрагмент с блипом
        ###
        return {
            t: " "
            params: @_createInlineBlipFragmentParams(blipId)
        }
    
    _createInlineBlipFragmentParams: (blipId) ->
        ###
        Создает параметры для фрагмента блипа
        ###
        return {
            "__TYPE": "BLIP"
            "__ID": blipId
        }
    
    _findBlipInnerReplies: (blipData, blipIds) ->
        ###
        возвращает фрагменты для блипов внутренних ответов
        он бывает только один у блипа
        ###
        res = []
        elementsBlips = {}
        for pos, element of blipData.elements
            if element.type == "INLINE_BLIP"
                elementsBlips[element.properties.id] = element.properties.id
        
        if blipData.replyThreadIds.length
            for replyBlipId in blipData.replyThreadIds
                if not elementsBlips[replyBlipId] and blipIds[replyBlipId]
                    fragment = @_createInlineBlipFragment(blipIds[replyBlipId])
                    res.push(fragment)
                    break
        return res
        
    _getBlipThread: (threadId, sourceData) ->
        ###
        Возвращает тред ответов для блипа
        ###
        if threadId == ""
            return sourceData.waveletData.rootThread
        else
            return sourceData.threads[threadId]
    
    _findBlipThreadReplies: (blipData, sourceData, blipIds) ->
        ###
        возвращает фрагменты для блипов ответов
        он бывает только один у блипа
        ###
        res = []
        thread = @_getBlipThread(blipData.threadId, sourceData)
        bId = blipData.blipId
        if thread.blipIds.length
            nextIsReply = false
            for tbId in thread.blipIds
                if nextIsReply
                    continue if not blipIds[tbId]
                    res.push(@_createSimpleLineFragment())
                    fragment = @_createInlineBlipFragment(blipIds[tbId])
                    res.push(fragment)
                    break
                nextIsReply = true if tbId == bId
        return res
        
    _createSimpleLineFragment: () ->
        return {
            t: " "
            params: {
                "__TYPE": "LINE"
                "RANDOM": @_random()
            }
        }
        
    _parseLink: (link) ->
        ###
        Заменяет ссылки вида
        waveid://googlewave.com/w+sVBcmzVLA/~/conv+root/b+sVBcmzVLF
        и
        https://wave.google.com/wave/waveref/googlewave.com/w+sVBcmzVLA/~/conv+root/b+sVBcmzVLF
        на
        /r/googlewave.com/w+sVBcmzVLA/~/conv+root/b+sVBcmzVLF
        ###
        if link.indexOf('waveid://') == -1 and link.indexOf('https://wave.google.com/wave/waveref/') == -1
            return link
        
        link = link.replace(/(waveid\:\/\/|https\:\/\/wave\.google\.com\/wave\/waveref\/)/, LINK_REDIRECT_PREFIX)
        link = link.replace('/~/', '/')
        return link
    
    _getAnnotationParams: (annotation, callback) ->
        params = {}
        switch annotation.name
            # @TODO: дописать все фороматирование
            when "style/fontWeight"
                params["T_BOLD"] = true if annotation.value == "bold"
                return params
            when "style/fontStyle"
                params["T_ITALIC"] = true if annotation.value == "italic"
                return params
            when "style/textDecoration"
                switch annotation.value
                    when 'underline' then params["T_UNDERLINED"] = true
                    when 'line-through' then params["T_STRUCKTHROUGH"] = true
                return params
            else
                if annotation.name in ["link/manual", "link/auto", "link/wave"]
                    return {"T_URL": @_parseLink(annotation.value) }
                else
                    return params
    
    _getAnnotationsParams: (annotations, startPos, endPos) ->
        ###
        Возвращает объект свойств для данного фрагмента
        ###
        params = {}
        params["__TYPE"] = "TEXT"
        for annotation in annotations
            if startPos >= annotation.range.start and endPos <= annotation.range.end
                _.extend(params, @_getAnnotationParams(annotation))
        return params

    _random: () ->
        return Math.random()
    
    _getElementParams: (element, blipIds, threads) ->
        # @TODO: написать все элементы
        switch element.type
            when "LINE"
                params = {
                    "__TYPE": "LINE"
                    "RANDOM": @_random()
                }
                if element.properties.indent or element.properties.lineType
                    indent = element.properties.indent
                    indent = if indent then parseInt(indent) else 0
                    params['L_BULLETED'] = indent
                return params
            when "INLINE_BLIP"
                return {"__TYPE": "TEXT"} if @_wasElementBlipIds[element.properties.id]
                blipId = blipIds[element.properties.id]
                if not blipId
                    thread = threads[element.properties.id]
                    if thread and thread.blipIds and thread.blipIds.length
                        blipId = blipIds[thread.blipIds[0]]
                @_wasElementBlipIds[element.properties.id] = element.properties.id
                #если нет id вернем просто текстовый фрагмент
                return {"__TYPE": "TEXT"} if not blipId
                return @_createInlineBlipFragmentParams(blipId)
            when "ATTACHMENT"
                return {
                    "__TYPE": "ATTACHMENT"
                    "__URL": element.properties.attachmentUrl
                }
            when "GADGET"
                params =
                    "__TYPE": "GADGET"
                _.extend(params, element.properties) 
                return params
            else
                return {}


module.exports =
    ImportSourceParser: new ImportSourceParser()
    LINK_REDIRECT_PREFIX: LINK_REDIRECT_PREFIX
