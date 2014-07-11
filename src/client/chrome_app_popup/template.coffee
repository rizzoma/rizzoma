ck = window.CoffeeKup

chromeAppPopupTmpl = ->
    div '.js-cap-overlay.cap-overlay', ''
    div '.js-chrome-app-popup.chrome-app-popup', ->
        text '''
        <script>(function(d, s, id) {
            if (window.navigator.userAgent.search("Chrome") == -1 && window.navigator.userAgent.search("Mobile") != -1) return;
            var js, fjs = d.getElementsByTagName(s)[0];
            if (d.getElementById(id)) return;
            js = d.createElement(s); js.id = id;
            js.src = "//connect.facebook.net/en_US/all.js#xfbml=1&appId=267439770022011";
            fjs.parentNode.insertBefore(js, fjs);
        }(document, "script", "facebook-jssdk"));</script>
        '''
        div '.internal-container', ->
            div '.js-cap-close.cap-close', {title: 'Close'}, ''
            div '.cap-title', 'Enjoy Rizzoma App on Chrome Web Store!'
            div '.cap-title', ->
                text 'Stay tuned for news and updates'
                text '<fb:like href="http://facebook.com/rizzomacom" send="false" layout="button_count" width="450" show_faces="true" font="arial" style="margin-left: 10px;"></fb:like>'
            a '.cap-link', {href:"https://chrome.google.com/webstore/detail/rizzoma-activity-stream/fnbgbbhkjiefjkpibiddeieeppnkjdgp?hl=en&gl=RU&from=enjoyrizzoma", target: '_blank'}, ->
                div '.cap-panel', ->
                    div '.logo', ''
                    div '.cap-link-info', ->
                        div '.title', 'Install Rizzoma app'
                        div '.via-web-store', ->
                            div '.cap-logo', ''
                            div '.cap-text', 'via Chrome Web Store'
            div '.cap-title', 'We support:'
            div '.support-services', ->
                div '.gmail', title: "Email integration: @mentions and tasks in your inbox, reply by email", ->
                    div '.logo', ''
                div '.hangout', title: "Discuss Rizzoma topic in Google+ Hangout. Select &quot;Start G+ Hangout&quot; from topic's Gear menu (right top corner)", ->
                    a {href: 'https://plus.google.com/100419497458726670190/posts/X1hexck7UD1', target: '_blank'}, ->
                        div '.logo', ''
                div '.gcal', title: "Sync your Tasks with Google Calendar. Click for instructions", ->
                    a {href: 'https://rizzoma.com/topic/c5e7d7138002d01e99467275792c61cb/', target: '_blank'}, ->
                        div '.logo', ''
                div '.gdrive', title: "Google Drive integration (planned)", ->
                    div '.logo', ''
                    div '.date', 'Planned'

exports.renderChromeAppPopup = ck.compile(chromeAppPopupTmpl)
