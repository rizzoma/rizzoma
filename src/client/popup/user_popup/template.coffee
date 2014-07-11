ck = window.CoffeeKup
BrowserSupport = require('../../utils/browser_support')
{getOtherUrl} = require('../../utils/url')

userComnonPopupTmpl = ->
    div '.js-user-popup-menu-top-block.user-popup-menu-top-block', ''
        
userTopPopupTmpl = ->
    div ->
        div '.wave-participant-avatar.avatar', {style:"background-image: url(#{h(@fixedAvatar || @avatar)})"}, h(@initials)# ->
        div '.wave-participant-name-email', ->
            div '.wave-participant-name', h(@name)
            div '.wave-participant-email', h(@email)
            if @skypeId
                skypeId = h(@skypeId)
                a '.skype-call-link', {href: "skype:#{skypeId}?call", title: "Call skype", target: 'skype-call-iframe'}, ->
                    text skypeId
                    img '.skype-status-ico', {src: "http://mystatus.skype.com/smallicon/#{skypeId}"}
            div '.js-user-popup-menu-remove-block.user-popup-menu-remove-block', ''
        div '.clearer', ''

exports.renderUserComnonPopup = ck.compile(userComnonPopupTmpl)

renderUserTopPopup = ck.compile(userTopPopupTmpl)
if BrowserSupport.isMozilla()
    # В firefox, начиная с 19-й версии есть баг: если одна и та же картинка на странице приводится к разным размера
    # background-size'ом, то firefox потребляет очень много процессорного времени. Изменим url картинки так, чтобы
    # адрес был разным, но картинка - той же
    orgRenderUserTopPopup = renderUserTopPopup
    renderUserTopPopup = (params={}) ->
        params.fixedAvatar = getOtherUrl(params.avatar)
        orgRenderUserTopPopup(params)


exports.renderUserTopPopup = renderUserTopPopup