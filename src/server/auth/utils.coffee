class AuthUtils
    constructor: () ->

    convertAuthListToProfile: (authList) ->
        ###
        Получает профайл из списка auth-документов.
        @param authList: array of AuthModel
        @return: object
        ###
        profile = {}
        profile[auth.getId()] = auth.getProfile() for auth in authList
        return profile

    getPasswordAuth: (authList, id) ->
        ###
        Из списка Auth-документов, возвращает password-авторизации.
        @param authList: array of AuthModel
        @param id: string
        @return AuthModel
        ###
        for auth in authList when auth.getSource() is 'password'
            return auth if not id or auth.getId() is id
        return null

module.exports.AuthUtils = new AuthUtils()