exports.getQuery = ->
    res = {}
    queryString = location.search.substring(1)
    re = /([^&=]+)=([^&]*)/g
    while m = re.exec(queryString)
        res[decodeURIComponent(m[1])] = decodeURIComponent(m[2]);
    res

exports.getOtherUrl = (url) ->
    # Fix для firefox: добавляем ничего не значящий get-параметр
    return url if not url
    return url + '#bsParam=big'