ck = window.CoffeeKup

introduceTmpl = ->
    div '.js-introduce.introduce', ->
        div '.background', ''
        div '.js-slides-container.slides-container', ->
            div '.js-slider-header.slider-header', ->
                div '.switch-to-video', ->
                    a '.switch-link.js-switch-link', ->
                        div '', 'Play video'
                        img '', {src: "/s/img/introduce/pv.png"}
                div '.js-navigation.navigation', ->
                    button '.js-prev.prev', {disabled: "disabled"}, ->
                        div '', 'Prev tip'
                    div '.js-progressbar.progressbar', ->
                        div '.progressbar-round.active', ''
                        for i in [2..@slidesCount]
                            div '.progressbar-round', ''
                    button '.js-next.next', ->
                        div '', 'Next tip'
                    div '.clearer', ''
                button '.js-closer.closer', ->
                    div '.close-txt', 'Check it later'
                    img '.close-img', {src: '/s/img/introduce/close.png'}
                    div '.clearer', ''
                div '.clearer', ''
            div ".js-slides.slide", ->
                div '.js-callout.callout.slide0', ''
            div ".js-video.video", ''

videoTmpl = ->
    iframe ''
        , {
            width: "640",
            height: "480",
            src: "https://www.youtube.com/embed/#{@videoUrl}?fs=1&hl=en_En&color1=0x2b405b&color2=0x6b8ab6&autoplay=1&autohide=1&wmode=transparent",
            frameborder:"0",
            allowfullscreen: 'true'
            webkitallowfullscreen: 'true'
            mozallowfullscreen: 'true'
          }

exports.renderIntro = ck.compile(introduceTmpl)

exports.renderVideo = ck.compile(videoTmpl)
