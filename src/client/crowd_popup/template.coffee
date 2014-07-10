ck = window.CoffeeKup

crowdPopupTmpl = ->
    div '.js-crowd-overlay.crowd-overlay', ''
    div '.js-crowd-popup.crowd-popup', ->
        div '.internal-container', ->
            div '.js-crowd-close.crowd-close', {title: 'Close'}, ''
            div '.crowd-title', 'Rizzoma Blesses the Crowd for help!'
            div '.crowd-text', ->
                span "Want to get in on Rizzoma's growth?"
                br ''
                a '.crowd-link', {
                    href: "https://rizzoma.com/topic/fafc9e77439da06f0675983a026ad892/?from=crowd_popup"
                    onClick: "_gaq.push(['_trackEvent', 'Crowd popup', 'link click', 'how to help'])"
                    target: '_blank'
                }, "Go to How You Can Help the Rizzoma"
            div '.crowd-text', ->
                span "Want to get Crowd for Your Project?"
                br ''
                a '.crowd-link', {
                    href: "https://rizzoma.com/topic/bb306e65888a84bc3164615ca66ec37d/?from=crowd_popup"
                    onClick: "_gaq.push(['_trackEvent', 'Crowd popup', 'link click', 'how to use'])"
                    target: '_blank'
                }, "Go to How to use Wisdom of the Crowd with Rizzoma"
            div '.crowd-text', ->
                input {type:"checkbox", id: "js-show-crowd-popup", checked:"#{if @scpCookie then 'checked' else ''}"}
                label {for:"js-show-crowd-popup"},'Ask me later'

exports.renderCrowdPopup = ck.compile(crowdPopupTmpl)
