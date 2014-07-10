IdUtils = require('../utils/id_utils').IdUtils
###
Утилиты для работы с персональными тегами.
###

PTAG_OFFSET = 8
###
На сколько будем сдвигать userId.
###

COMMON_PTAGS =
    ###
    Персональные теги, которые будут у каждого пользователя.
    ###
    ALL: 0
    FOLLOW: 255
    UNFOLLOW: 254

class Ptag
    constructor: () ->
        @ALL_PTAG_ID = COMMON_PTAGS.ALL
        @FOLLOW_PTAG_ID = COMMON_PTAGS.FOLLOW
        @UNFOLLOW_PTAG_ID = COMMON_PTAGS.UNFOLLOW

    getCommonPtagId: (ptagName) ->
        ###
        Возвращает id тэга по имени.
        Если имени не нашлось - вернет id тэга ALL
        @param ptagName: string
        @returns: int
        ###
        return COMMON_PTAGS[ptagName] or COMMON_PTAGS['ALL']


    getSearchPtagIdByName: (user, ptagName) ->
        ###
        Возвращает id пользователя скомбинированный с id тэга,
        полученному по его имени.
        @param user: UserModel || string
        @param ptagName: string
        @returns: int
        ###
        ptagId = @getCommonPtagId(ptagName)
        return @getSearchPtagId(user, ptagId)

    getSearchPtagId: (user, ptagId) ->
        ###
        Возвращает id пользователя скомбинированный с id тэга.
        @param: user: UserModel || string
        @param: ptagId: int
        @returns int
        ###
        return null if not ptagId?
        userId = if typeof(user) == 'string' then IdUtils.getOriginalId(user) else user.getOriginalId()
        return null if not userId
        return @_idsToPtag(userId,  ptagId)

    getSearchPtagIdsByName: (user, ptagName) ->
        ###
        Аналогично @getSearchPtagIdByName, но возвращает список, для кажлого id (alternativeIds + id)
        @param user: UserModel
        @param ptagName: string
        @returns: array
        ###
        ptagId = @getCommonPtagId(ptagName)
        return @getSearchPtagIds(user, ptagId)

    getSearchPtagIds: (user, ptagId) ->
        ###
        Аналогично @getSearchPtagId, но возвращает список, для кажлого id (alternativeIds + id)
        @param user: UserModel
        @param ptagName: string
        @returns: array
        ###
        return null if not ptagId?
        userIds = user.getAllIds()
        return null if not userIds.length
        return (@_idsToPtag(IdUtils.getOriginalId(id), ptagId) for id in userIds)

    _idsToPtag: (userId, ptagId) ->
        userId <<= PTAG_OFFSET
        return userId | ptagId

    parseSearchPtagId: (searchPtagId) ->
        ###
        Обратная к getSearchPtagId функция.
        Возвращает id пользователя и id тэга.
        @param: searchPtagId: int
        @returns [string, int] - [id пользователя, id тэга]
        ###
        searchPtagId = parseInt(searchPtagId, 10)
        return [null, null] if not searchPtagId
        userId = searchPtagId >> PTAG_OFFSET
        ptagId = searchPtagId ^ (userId << PTAG_OFFSET)
        return [IdUtils.getId('u', userId), ptagId]

module.exports.Ptag = new Ptag()
