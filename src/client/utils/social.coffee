self = module.exports

self.addPlusoneScript = ->
    do ->
        po = document.createElement 'script'
        po.type = 'text/javascript'
        po.async = true
        po.src = 'https://apis.google.com/js/plusone.js'
        s = document.getElementsByTagName('script')[0]
        s.parentNode.insertBefore(po, s)

self.addFacebookScript = ->
    do (document) ->
        return if (window.navigator.userAgent.search("Chrome") == -1 && window.navigator.userAgent.search("Mobile") != -1)
        fjs = document.getElementsByTagName("script")[0]
        return if (document.getElementById("facebook-jssdk"))
        js = document.createElement("script")
        js.id = "facebook-jssdk"
        js.src = "//connect.facebook.net/en_US/all.js#xfbml=1&appId=267439770022011"
        fjs.parentNode.insertBefore(js, fjs)