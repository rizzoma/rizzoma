ck = window.CoffeeKup

commonFormTmpl = ->
    div '.js-ctm.ctm', ->
        div ".ctm-left-arrow", ->
            div '', ''
        div '.internal-container', ->
            div '.wizard-form', ->
                div '.first-step', ->
                    div '.digit.digit1', '1'
                    div '.ctm-title', ->
                        div '.title', ->
                            text 'Enter subject'
                            a '.js-toggle-video.toggle-video', ->
                                span '.js-toggle-video-text', 'Show video'
                                img {src: '/s/img/play-icon.png'}
                        input '.js-topic-title', {type: "text", title: "Topic title"}
                        div '.clearer', ''
                div '.delimiter.d1', ''
                div '.second-step', ->
                    div '.digit.digit2', '2'
                    div '.js-ctm-contact-picker.ctm-add-participant', ->
                        div '.title', 'Add participants'
                    div '.clearer', ''
                div '.delimiter.d2', ''
                div '.third-step', ->
                    div '.digit.digit3', '3'
                    div '.create-button', ->
                        button ".js-ctm-create-topic.ctm-create-topic", "Create new topic"
                        div ".ctm-dont-show", ->
                            input '.js-ctm-dont-show', {id: "ctm-dont-show", type: "checkbox"}
                            label for:"ctm-dont-show", "Don't show wizard"
                    div '.clearer', ''
            div '.js-wizard-video.wizard-video', ''

wizardVideoTmpl = ->
    iframe {
        id: "js-wizard-videoplayer"
        width: "512",
        height: "384",
        src: "https://www.youtube.com/embed/I7whBwsGzM8?fs=1&hl=en_En&color1=0x2b405b&color2=0x6b8ab6&autoplay=1&autohide=1&wmode=transparent",
        frameborder:"0",
        allowfullscreen: 'true'
        webkitallowfullscreen: 'true'
        mozallowfullscreen: 'true'
    }

decorateTmpl = ->
    hideWizard = if !@wizardDefault then '.hide-wizard' else ''
    div ".js-ctm-create-button.ctm-create-button#{hideWizard}", ->
        if @wizardDefault
            div 'New'
    div '.js-ctm-overlay.ctm-overlay', ''

commonCreateButtonTmpl = ->
    button '.js-create-wave-by-wizard.common-create-wave-by-wizard', {title:"Create new topic with wizard", disabled: "disabled" if not window.loggedIn}, ->
        div 'New'
        div '.wizard-icon', ''

differenceCreateButtonsTmpl = ->
    button '.js-create-wave.js-common-create-wave.create-wave', {title:"Create new topic", disabled: "disabled" if not window.loggedIn}, ->
        div 'New'
    button '.js-create-wave-by-wizard.create-wave-by-wizard', {title:"Create new topic with wizard", disabled: "disabled" if not window.loggedIn}, ->
        div '.wizard-icon', ''

createGDriveWaveButtonTmpl = ->
    params = {title: 'Create new topic', href: h(@url), target: '_blank'}
    params.disabled = 'disabled' if not window.loggedIn
    a 'create-gdrive-wave button', params, ->
        div 'New'
        div 'gdrive-icon16', ''

exports.renderCommonForm = ck.compile(commonFormTmpl)

exports.renderDecorate = ck.compile(decorateTmpl)

exports.renderCommonCreateButton = ck.compile(commonCreateButtonTmpl)

exports.renderDifferenceCreateButtons = ck.compile(differenceCreateButtonsTmpl)

exports.renderGDriveCreateButton = ck.compile(createGDriveWaveButtonTmpl)

exports.renderVideo = ck.compile(wizardVideoTmpl)