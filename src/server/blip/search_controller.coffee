_= require('underscore')
async = require('async')
SearchController = require('../search/controller').SearchController
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Ptag = require('../ptag').Ptag
SHARED_STATE_PUBLIC = require('../wave/constants').SHARED_STATE_PUBLIC

class BlipSearchController extends SearchController
    ###
    Процессор поисковой выдачи при поиске по блипам в публичных волнах.
    ###
    constructor: () ->
        super()
        @_idField = 'wave_id'
        @_changedField = 'groupchanged'
        @_ptagField = 'ptags'

    searchBlips: (user, queryString, ptagNames, lastSearchDate, callback) ->
        return if @_returnIfAnonymous(user, callback)
        query = @_getQuery()
            .select(['wave_id', 'MAX(changed) AS groupchanged', 'MAX(content_timestamp) AS groupdate', 'wave_url', 'ptags'])
            .addPtagsFilter(user, ptagNames)
            .addQueryString(queryString)
            .groupBy('wave_id')
            .orderBy('groupdate')
            .defaultLimit()
        @executeQuery(query, lastSearchDate, user, ptagNames, callback)

    searchPublicBlips: (user, queryString, lastSearchDate, callback) ->
        query = @_getQuery()
            .select(['wave_id', 'MAX(changed) AS groupchanged', 'MAX(content_timestamp) AS groupdate', 'wave_url', 'ptags'])
            .addQueryString(queryString)
            .addAndFilter("shared_state = #{SHARED_STATE_PUBLIC}")
            .groupBy('wave_id')
            .orderBy('groupdate')
            .defaultLimit()
        @executeQuery(query, lastSearchDate, user, null, callback)

    _getItem: (result, changed, user, ptagNames) ->
        item = {waveId: result.wave_url}
        return item if not changed
        item.changeDate = result.groupdate
        if @_hasAllPtag(ptagNames)
            #если запрос всех топиков, то нужно поставить галочку follow, что бы нарисовать правильную кнопку на клиенте
            item.follow = true if @_isFollow(result, user)
        return item

    _hasAllPtag: (ptagNames) ->
        ###
        Возвращает true если среди тэгов есть ALL
        @param ptagNames: string
        @returns bool
        ###
        return true if not ptagNames
        ptagNames = [ptagNames] if not _.isArray(ptagNames)
        for ptagName in ptagNames
            return true if Ptag.getCommonPtagId(ptagName) == Ptag.ALL_PTAG_ID
        return false

    _isFollow: (result, user) ->
        ###
        Опреляет, подписан ли пользователь на данную волну.
        @param result: object
        @param user: UserModel
        @returns: bool
        ###
        for searchPtagId in result.ptags
            [userId, ptagId] = Ptag.parseSearchPtagId(searchPtagId)
            continue if not userId? or not ptagId?
            continue if not user.isEqual(userId)
            continue if ptagId != Ptag.FOLLOW_PTAG_ID
            return true
        return false

    _getChangedItems: (ids, user, ptagNames, callback) ->
        @_getWavesAndStuffIds(ids, (err, waves, rootBlipsIds, creatorsIds) =>
            return callback(err, null) if err
            return callback(null, {}) if not ids.length
            tasks = [
                (callback) ->
                    CouchBlipProcessor.getByIdsAsDict(rootBlipsIds, callback)
                (callback) ->
                    UserCouchProcessor.getByIdsAsDict(creatorsIds, callback, false, true)
                (callback) =>
                    @_getReadBlipCounts(ids, user, callback)
                (callback) =>
                    @_getTotalBlipCounts(ids, user, callback)
            ]

            async.parallel(tasks, (err, result) =>
                return callback(err) if err
                @_compileItems(waves, result..., callback)
            )
        )

    _getWavesAndStuffIds: (ids, callback) =>
        ###
        Получет волны и id корневых блипов и авторов.
        @param ids: array
        @param callback: function
        ###
        rootBlipsIds = []
        creatorsIds = []
        CouchWaveProcessor.getByIdsAsDict(ids, (err, waves) ->
            return callback(err) if err
            for own id, wave of waves
                rootBlipsIds.push(wave.rootBlipId)
                creatorId = wave.getTopicCreator()?.id
                creatorsIds.push(creatorId) if creatorId
            callback(null, waves, rootBlipsIds, creatorsIds)
        )

    _getTotalBlipCounts: (waveIds, user, callback) =>
        ###
        Получет количество блипов волнах.
        @param waveIds: array
        @param user: object
        @param callback: function
        ###
        return callback() if user.isAnonymous()
        viewParams =
            group: true
            keys: waveIds
        CouchWaveProcessor.view('total_blip_count_by_wave_id_2/get', viewParams, (err, counts) =>
            return callback(err, null) if err
            callback(null, @_convertCountsToDict(counts))
        )

    _getReadBlipCounts: (waveIds, user, callback) =>
        ###
        Получает количество прочитанных блипов волнах.
        @param waveIds: array
        @param participantId: string
        @param callback: function
        ###
        return callback() if user.isAnonymous()
        keys = []
        for waveId in waveIds
            for userId in user.getAllIds()
                keys.push([waveId, userId])
        viewParams =
            group: true
            keys: keys
        #stale: "ok"
        CouchWaveProcessor.view('read_blip_count_by_wave_id_and_participant_id_2/get', viewParams, (err, counts) =>
            return callback(err, null) if err
            callback(null, @_convertCountsToDict(counts))
        )

    _convertCountsToDict: (counts) ->
        ###
        Конвертирут результат выполнения @_getTotalBlipCounts и @_getReadBlipCounts
        в человеческий вид - раскаладывает цифирки по id волн.
        @param counts: array
        @returns object
        ###
        countsByWaveId = {}
        for count in counts
            waveId = count.key
            waveId = if _.isArray(waveId) then waveId[0] else waveId
            countsByWaveId[waveId] = count.value
        return countsByWaveId

    _compileItems: (waves, blips, creators, readBlipsStat, totalBlipStat, callback) ->
        ###
        Собирает выдачу для изменившихся результатов поиска.
        @param waves: object
        @param blips: object - корневые блипы
        @param creators: object - авторы
        @param stats: object - статистика
        @returns: object
        ###
        items = {}
        for own id, wave of waves
            blip = blips[wave.rootBlipId]
            creatorId = wave.getTopicCreator()?.id
            creator = if creatorId then creators[creatorId] else null
            total = if totalBlipStat then totalBlipStat[id] else 0
            read = if readBlipsStat and readBlipsStat[id] then readBlipsStat[id] else 0
            if not (blip? and creator? and total?)
                if not blip?
                    # Это может произойти только из-за хитрой ошибки, потому как несуществующий блип свалит всю обработку поиска
                    console.warn("Got search result for blip #{id} but could not load wave root blip #{wave.rootBlipId}")
                if not creator?
                    console.warn("Got search result for blip #{id} but could not load wave creator #{creatorId}")
                if not total?
                    console.warn("Got search result for blip #{id} but could not load total blip stat for this blip")
                continue
            items[id] =
                title: blip.getTitle()
                snippet: blip.getSnippet()
                avatar: creator.avatar
                name: creator.name
                totalBlipCount: total
                totalUnreadBlipCount: total - read
                isTeamTopic: wave.isTeamTopic()
        callback(null, items)

module.exports =
    BlipSearchController: new BlipSearchController()
