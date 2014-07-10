getUserInitials = require('../../share/user/utils').getUserInitials
contactsConstants = require('../../share/contacts/constants')
LOADING_USER_NAME = '(...)'
UNKNOWN_USER_NAME = '(unknown)'
PUBLIC_USER_NAME = 'public'
ANONYMOUS_USER_ID = '0_user_0'
getAbsoluteUrl = (relative) ->
    return relative if relative.indexOf('http') is 0 #URL with host name
    return "#{location.protocol}//#{window.HOST}#{relative}"
ANONYMOUS_ICON_SRC = getAbsoluteUrl('/s/img/user/anonim.png')
UNKNOWN_ICON_SRC = getAbsoluteUrl('/s/img/user/unknown.png')
EMPTY_ICON_SRC = getAbsoluteUrl('/s/img/user/empty.png')

class User
    constructor: (@_id, @_email=null, @_name=null, @_avatar=null, @_extra=null, @_source=null, @_skypeId=null, @_loaded=yes) ->
        if @isAnonymous()
            @_name = PUBLIC_USER_NAME
            @_avatar = ANONYMOUS_ICON_SRC
            @_loaded = yes
        @lastRequestedTime = 0

    toObject: () ->
        ###
        Сериализует модель в Javascript-объект
        ###
        return {
            id: @_id
            email: @getEmail()
            name: @getName()
            avatar: @getAvatar()
            initials: @getInitials()
            extra: @_extra
            source: @_source
            skypeId: @_skypeId
        }

    isAnonymous: ->
        ###
        Возвращает true, если текущий пользователй является анонимным, иначе false
        ###
        return @_id is ANONYMOUS_USER_ID

    isLoaded: ->
        ###
        Возвращает true, если модель содержит обновленную информацию, полученную с сервера, иначе false
        ###
        @_loaded

    updateInfo: (@_email, @_name, @_avatar, @_extra, @_source, @_skypeId) ->
        ###
        Обновление модели пользователя
        ###
        @_loaded = yes

    getId: ->
        ###
        Возвращает идентификатор модели
        @returns string
        ###
        @_id

    getName: ->
        ###
        Возвращает отображаемое имя пользователя
        @returns string
         ###
        return @_name if @_name
        email = @getEmail()
        return email if email
        UNKNOWN_USER_NAME

    getRealName: ->
        @_name

    getInitials: ->
        getUserInitials(@_avatar, @_name)

    getAvatar: ->
        ###
        Возвращает  URL к иконке пользователя
        @returns: string
        ###
        return @_avatar if @_avatar
        UNKNOWN_ICON_SRC

    getEmail: ->
        ###
        Возвращает email пользователя
        @returns: string
        ###
        return @_email if @_email?
        if window.userInfo?
            return window.userInfo.email if @_id is window.userInfo.id
        return ''

    getSkypeId: -> @_skypeId

    getSearchString: ->
        ###
        Возвращает строку, по которой нужно искать autocomplete'у
        @returns: string
        ###
        "#{@getName()} #{@getEmail()}".toLowerCase()

    getDataForAutocomplete: (isParticipant) ->
        ###
        Возвращает данные для рендеринга контакта
        @param isParticipant: boolean
        @returns: object
        ###
        {
            isParticipant,
            id: @getId()
            name: @getName()
            email: @getEmail()
            avatar: @getAvatar()
            initials: @getInitials()
            source: @_source
        }

    fromGoogle: ->
        @_source == contactsConstants.SOURCE_NAME_GOOGLE

    fromManually: ->
        @_source == contactsConstants.SOURCE_NAME_MANUALLY

    isNewUser: ->
        ###
        Определяем заходил ли пользователь в ризому
        @returns: bool
        ###
        !@_avatar and !@_name

    @getUserStub: (id) ->
        ###
         Создает заглушку для пользователя
         @returns: User
         ###
        new User(id, null, LOADING_USER_NAME, EMPTY_ICON_SRC, null, null, null, no)

class UserAuth
    constructor: (@_id=null, @auth_type=null, @auth_id=null, @user_id=null) ->

module.exports.User = User
module.exports.UserAuth = UserAuth
module.exports.UNKNOWN_ICON_SRC = UNKNOWN_ICON_SRC