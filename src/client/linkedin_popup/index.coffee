ck = window.CoffeeKup
{BONUS_TYPE_LINKEDIN_LIKE} = require('../../share/constants')
{Request} = require('../../share/communication')
{LocalStorage} = require('../utils/localStorage')

linkedinPopupTmpl = ->
    div '.js-linkedin-popup-overlay.linkedin-popup-overlay', ''
    div '.js-linkedin-popup-container.linkedin-popup-container', ->
        div '.js-linkedin-popup.linkedin-popup', ->
            div '.js-close.close', ''
            div '.content', ->
                div '.title', 'Good news everyone!'
                div '.good-news', ->
                    text 'Share us on Linkedin and get '
                    span '.bonus-color', '1Gb free'
                    text '.'
                div 'Rizzoma is a safe way to communicate'
                ul ->
                    li 'Secure Sockets Layer (SSL) crypto protocol'
                    li 'Secure Amazon cloud hosting'
                div ->
                    a {href: '/about-security.html?from=linkedin_popup', target: '_blank'}, 'Click here'
                    text ' to learn more'
                div '.linkedin-share-button', ->
                    script {type:"IN/Share", "data-counter": "top", "data-onsuccess":"onSuccessShare", "data-url": "http://rizzoma.com/"}

renderLinkedinPopup = ck.compile(linkedinPopupTmpl)

class LinkedinPopup
    constructor: ->
        $(document.body).append(renderLinkedinPopup())
        @_overlay = $('.js-linkedin-popup-overlay')
        @_container = $('.js-linkedin-popup')
        @_closeCtrl = @_container.find('.js-close')
        window.onSuccessShare = @_onSuccessShare
        _gaq.push(['_trackEvent', 'LinkedIn popup', 'Open linkedin popup'])
        LocalStorage.setLinkedinPopupShowed()
        @_closeCtrl.on 'click', =>
            @_overlay.remove()
            @_container.remove()
            delete window.onSuccessShare

    _onSuccessShare: ->
        _gaq.push(['_trackEvent', 'LinkedIn popup', 'Share on linkedin', 'linkedin popup'])
        request = new Request({bonusType: BONUS_TYPE_LINKEDIN_LIKE}, (err) =>
            return console.error err
            _gaq.push(['_trackEvent', 'LinkedIn popup', 'Shared'])
        )
        require('../modules/root_router').instance.handle('network.user.giveBonus', request)

exports.LinkedinPopup = LinkedinPopup