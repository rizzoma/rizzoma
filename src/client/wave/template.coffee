ck = window.CoffeeKup

waveTmpl = ->
    ###
    Шаблон волны
    ###
    getShareSettingsPopup = ->
        div 'js-gdrive-share-menu popup-menu-container gdrive-menu-container hidden', ->
            div 'internal-container', ->
                div 'settings-menu', ->
                    if @gDriveShareUrl
                        a {href: h(@gDriveShareUrl), target: '_blank'}, 'Share via Google Drive'
                    a 'js-add-block-button js-btn', {href: '#'}, 'Share via Rizzoma'
                    a 'js-share-window-button js-btn', {href: '#'}, 'Make Public/Shared by link'

    div '.js-scroll-up .js-scroll .drag-scroll-up', ->
        div '.js-scroll-u-1000 .scroll-20', {offset: '-1000'}
        div '.js-scroll-u-500 .scroll-20', {offset: '-500'}
        div '.js-scroll-u-250 .scroll-20', {offset: '-250'}
        div '.js-scroll-u-50 .scroll-20', {offset: '-50'}
    div '.js-wave-header.wave-header', ->
        if not @empty
            if @isAnonymous
                div '.anonymous-login-container', ->
                    text 'Feel free to add info, ask question or comment'
                    a '.js-enter-rizzoma-btn.btn.sign-in-btn', { href: "/topic/", title: "Sign in"}, ->
                        text 'Enter Rizzoma'
            else
                if not @isGDriveView
                    div '.js-add-participant-block.add-participant-block', ->
                        button '.js-add-block-button.add-block-button', 'Invite'
                        div '.js-add-form.add-form', ''
            if @isAnonymous
                div '.anonymous-wave-info', ->
                    span '.participants-caption', 'Participants:'
                    div '.js-wave-participants.wave-participants', ''
                return
            div '.js-wave-participants.wave-participants', ''
            div '.js-share-container.share-section.wave-header-section' ,->
                button "js-show-share-button wave-share-button #{if @gDriveShareUrl then 'gdrive' else ''}", ->
                    div '.lock', ''
                    div 'gdrive-icon16', ''
                    text 'Share'
                if @isGDriveView
                    getShareSettingsPopup()
                    div '.js-add-participant-block.add-participant-block', ->
                        div '.js-add-form.add-form', ''
                div '.js-share-window.wave-share-popup hidden', ->
                    div '.internal-container', ->
                        div '.wave-url-sharing', ->
                            div '.wave-url-container', ->
                                input '.js-wave-url.wave-url', {type: "text", value: "#{@url}", readonly: 'readonly'}
                            div '.js-social-section.social-section', ->
                                div '.js-social-overlay.social-overlay', {title: "To share topic on social networks make it Shared by link or Public"}
                                button '.js-social-facebook.social-facebook', {title: "Share topic on Facebook"}
                                button '.js-social-google.social-google', {title: "Share topic on Google+"}
                                button '.js-social-twitter.social-twitter', {title: "Share topic on Twitter"}
                        div '.wave-share-window-delimiter', ''
                        div '.make-public-section', ->
                            label '.sharing-section', ->
                                input '.js-is-private-button', {type: 'radio', name: 'privacy'}
                                div '.description', ->
                                    div '.description-icon', ->
                                        img '', {src: '/s/img/sharing_lock.png'}
                                    div '.description-text', ->
                                        span 'Private.'
                                        span '.section-details', " Only listed participants can access. Sign-in required."
                            label '.sharing-section.by-link', ->
                                input '.js-by-link-button', {type: 'radio', name: 'privacy'}
                                div '.description', ->
                                    div '.description-icon', ->
                                        img '', {src: '/s/img/sharing_link.png'}
                                    div '.description-text', ->
                                        span 'Anyone with the link.'
                                        span '.section-details', ->
                                            text " Anyone who has the link can "
                                            a '.new-participant-role-select.js-shared-role-select', 'edit'
                                            text "."
                            label '.sharing-section.public', ->
                                input '.js-is-public-button', {type: 'radio', name: 'privacy'}
                                div '.description', ->
                                    div '.description-icon', ->
                                        img '', {src: '/s/img/sharing_unlock.png'}
                                    div '.description-text', ->
                                        span 'Public on the web.'
                                        span '.section-details', ->
                                            text " Anyone can find and "
                                            a '.new-participant-role-select.js-public-role-select', 'edit'
                                            text "."
                        return unless @gDriveShareUrl
                        hr ''
                        div style: 'color: #000; font-size: 13px; line-height: normal;', ->
                            span 'This topic was shared via Google Drive '
                            a 'button', {target: '_blank', href: h(@gDriveShareUrl)}, 'Settings'
            div '.js-saving-message.saving-message.wave-header-section', ->
                div '.js-saving-message-saving', 'Saving topic...'
                div '.js-saving-message-saved', 'Topic saved'
        div '.js-settings-container.wave-header-section.settings-section', ''
        div '.clearer', ''
    div '.js-topic-tip.topic-tip', ->
        span '.js-topic-tip-text.topic-tip-text', ''
        div '.tip-management', ->
            button '.js-next-tip.next-tip', 'Next tip '
            button '.js-hide-topic-tip.hide-topic-tip', 'Close'
    div '.js-wave-panel.wave-panel', ''
    contentClasses = '.js-wave-content.wave-content'
    contentClasses += '.no-editing' if @isAnonymous
    div contentClasses, ->
        if not @empty
            div '.js-wave-blips.wave-blips', ->
                div '.js-container-blip container-blip', ''#->
                if not @isAnonymous
                    div 'topic-url', ->
                        a 'js-topic-url', {href: @url}, 'Open as topic'
            div '.js-topic-mindmap-container.topic-mindmap-container', ''
    div '.js-scroll-down .js-scroll .drag-scroll-down', ->
        div '.js-scroll-d-50 scroll-20', {offset: '50'}
        div '.js-scroll-d-250 scroll-20', {offset: '250'}
        div '.js-scroll-d-500 scroll-10', {offset: '500'}
        div '.js-scroll-d-1000 scroll-10', {offset: '1000'}

waveHeaderTmplMobile = ->
    section 'header js-wave-header', ->
        div 'wrapper', ->
            if @isAnonymous
                div '.anonymous-login-container', ->
                    a '.js-enter-rizzoma-btn.btn.sign-in-btn', { href: "/topic/?mode=mobile", title: "Sign in"}, ->
                        text 'Sign in'
            button "js-back-button.header-button.back-button", ->
                div 'icon', ''
            button "js-toggle-edit-mode active-blip-control.header-button.edit-button", {disabled: 'disabled'}, ->
                span 'Edit'
            button "js-insert-reply.active-blip-control.header-button.reply-button", {disabled: 'disabled'}, ->
                div 'icon', ''
            button "js-insert-mention.active-blip-control.header-button.mention-button", {disabled: 'disabled'}, ->
                div 'icon', ''
            button "js-hide-replies-button.active-blip-control.header-button.collapse-button", {disabled: 'disabled'}, ->
                div 'icon', ''
            button "js-show-replies-button.active-blip-control.header-button.expand-button", {disabled: 'disabled'}, ->
                div 'icon', ''
            button 'js-next-unread-button header-button next-unread-button', {disabled: 'disabled'}, ->
                span style: "display: inline-block;", 'Next'
                div 'icon', ''

waveContentTmplMobile = ->
    ###
    Шаблон волны
    ###
    div '.js-wave-content.wave-content', ->
        if not @empty
            div '.wave-blips', ->
                div '.js-container-blip container-blip', ->
                div '.js-root-blip-menu.root-blip-menu', ->
                    div '.menu-content', ->
                        div '.root-button-delimiter', ''
                        button '.js-root-reply-button.root-reply-button', {disabled: 'disabled'}, ->
                            img '', {src: '/s/img/ico_reply.png'}
                            text 'Reply'
                        div '.root-button-delimiter', ''
                        div '.clearer', ''

likesForAnonymousPublic = ->
    div '.public-like', ->
        text '<fb:like href="http://facebook.com/rizzomacom" send="false" layout="button_count" width="95" show_faces="false" font="verdana" style="top: -3px;"></fb:like>'
    div '.public-like', ->
        a '.twitter-share-button', href: "https://twitter.com/share"
        text '  <script>
                    !function(d,s,id){
                        var js,fjs=d.getElementsByTagName(s)[0];
                        if(!d.getElementById(id)){js=d.createElement(s);
                            js.id=id;
                            js.src="//platform.twitter.com/widgets.js";
                            fjs.parentNode.insertBefore(js,fjs);
                        }}(document,"script","twitter-wjs");
                </script>'
    div '.public-like', ->
        text '  <script type="text/javascript">
                    function googleLikeCallback(e) {
                        if (e.state == "on") _gaq.push(["_trackEvent", "Social", "+1", "public anonymous"]);
                    }
                </script>
                <g:plusone size="medium" callback="googleLikeCallback"></g:plusone>
                <script type="text/javascript">
                    (function() {
                        var po = document.createElement("script"); po.type = "text/javascript"; po.async = true;
                        po.src = "https://apis.google.com/js/plusone.js";
                        var s = document.getElementsByTagName("script")[0]; s.parentNode.insertBefore(po, s);
                    })();
                </script>'
    div '.clearer', ''

selectAccountTypeBannerTmpl = ->
    div '.js-account-wizard-banner.account-wizard-banner', ->
        div '.js-close-account-wizard-banner.close-account-wizard-banner', ->
            text 'Close'
            img src: '/s/img/close-account-select-banner.png'
        img src: "/s/img/logo/for-select-acc-banner.png"
        div '.content-block', ->
            span "js-open-account-select open-account-select", "Click here"
            span " to upgrade your account"

exports.renderWave = ck.compile(waveTmpl)

exports.renderWaveHeaderMobile = ck.compile(waveHeaderTmplMobile)

renderContentMobile = ck.compile(waveContentTmplMobile)

exports.renderWaveMobile = (params = {}) ->
    exports.renderWaveHeaderMobile(params) + renderContentMobile(params)
    
exports.renderLikesForAnonymousPublic = ck.compile(likesForAnonymousPublic)

exports.renderSelectAccountTypeBanner = ck.compile(selectAccountTypeBannerTmpl)