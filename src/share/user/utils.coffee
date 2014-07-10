exports.getUserInitials = (avatar, name) ->
    return '' if avatar or not name
    nameWords = name.split(' ')
    return '' if nameWords.length < 2
    return "#{nameWords[0][0]}#{nameWords[nameWords.length-1][0]}".toUpperCase()