exports.isRobot = (req) ->
    if 'x-goog-source' of req.headers
        return true
    userAgent = req.headers['user-agent']
    if not userAgent
        return false
    return /Googlebot|AdsBot-Google|bingbot|msnbot|facebookexternalhit|Google \(\+https:\/\/developers.google.com\/\+\/web\/snippet\/\)|LinkedInBot|YandexBot|Mail\.RU_Bot/.test(userAgent)
