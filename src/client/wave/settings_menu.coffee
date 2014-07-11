{Request} = require('../../share/communication')
{popup, PopupContent} = require('../popup')
EmbeddedCodeGenerator = require('./embedded_code_generator_window')
BrowserEvents = require('../../utils/browser_events')

ck = window.CoffeeKup

buttonTmpl = ->
    button '.js-show-settings-button.wave-header-button.show-settings-button', {title: 'Show settings'}
    
popupTmpl = ->
    div '.settings-menu', ->
        a '.js-read-all', {href: '#', title: "Mark this topic as read"}, 'Mark topic as read'
        a '.js-follow-topic', {href: '#', title: "Follow topic"}, 'Follow'
        a '.js-unfollow-topic', {href: '#', title: "Unfollow topic"}, 'Unfollow'
        if not window.userInfo?.inIframe
            a '.js-start-hangout', {
                href: "https://talkgadget.google.com/hangouts?gid=#{h(window.socialSharingConf.hangoutAppId)}&gd=#{h(@topicId)}"
                target: '_blank'
                title: "Start Google+ Hangout with Rizzoma topic embedded"
            }, 'Start G+ Hangout'
        a '.js-print-topic', {href: '#', title: 'Print topic contents'}, 'Print'
        if @exportUrl
            a '.js-single-export', {href: @exportUrl, target: '_blank', title: 'Export opened topic as HTML'}, 'Export single topic'
        a '.js-multi-export', {href: '#', title: 'Export multiple topics as ZIP-archive'}, 'Export multiple topics'
        if @embeddedUrl
            a '.js-embedded', {href: '#', title: 'Get embedded code'}, 'Get embedded code'

renderButton = ck.compile(buttonTmpl)
renderPopup = ck.compile(popupTmpl)

class SettingsPopup extends PopupContent
    
    constructor: (button, params) ->
        container = $(renderPopup(params))
        @_container = container[0]
        @_initReadAllButton(container, button)
        @_initFollowAndUnfollowButtons(container, params.topicId)
        @_initPrintButton(container)
        @_initHangoutButton(container)
        @_initSingleExportButton(container)
        @_initMultiExportPopup(container, button)
        @_initGetEmbeddedButton(container, params.embeddedUrl)

    _initReadAllButton: ($container, button) ->
        $container.find('.js-read-all').click =>
            _gaq.push(['_trackEvent', 'Topic content', 'Mark topic as read'])
            event = BrowserEvents.createCustomEvent(BrowserEvents.C_READ_ALL_EVENT, yes, yes)
            button.dispatchEvent(event)
            popup.hide()

    _initFollowAndUnfollowButtons: (container, topicId) ->
        processor = require('../search_panel/topic/processor').instance
        button = container.find('.js-follow-topic')
        button.click ->
            _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make followed by settings menu'])
            processor.followTopic topicId, ->
                popup.hide()
            return false
        button = container.find('.js-unfollow-topic')
        button.click ->
            _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make unfollowed by settings menu'])
            processor.unfollowTopic topicId, ->
                popup.hide()
            return false

    _initPrintButton: (container) ->
        button = container.find('.js-print-topic')
        button.click ->
            _gaq.push(['_trackEvent', 'Topic content', 'Print topic'])
            window.print()
        
    _initHangoutButton: (container) ->
        button = container.find('.js-start-hangout')
        button.click ->
            _gaq.push(['_trackEvent', 'Hangout', 'Hangout click']);

    _initSingleExportButton: (container) ->
        button = container.find('.js-single-export')
        button.click ->
            _gaq.push(['_trackEvent', 'Topic content', 'Export single topic']);

    _initMultiExportPopup: (container, button) ->
        {showExportPopup} = require('../export')
        container.find('.js-multi-export').click (e) ->
            e.preventDefault()
            _gaq.push(['_trackEvent', 'Topic content', 'Export multiple topics'])
            request = new Request null, (error, topics) ->
                showExportPopup(topics, button) if topics
            router = require('../app').router
            router.handle('navigation.loadTopicList', request)

    _initGetEmbeddedButton: (container, url) ->
        container.find('.js-embedded').click ->
            _gaq.push(['_trackEvent', 'Topic content', 'Get embedded code'])
            EmbeddedCodeGenerator.get().open(url)
            popup.hide()
        
    destroy: ->
        
    getContainer: ->
        return @_container

        
class SettingsMenu
    
    _initButton: (container, params) ->
        button = container.find('.js-show-settings-button')
        button.bind 'click', ->
            _gaq.push(['_trackEvent', 'Settings', 'Settings click'])
            popup.hide()
            popup.render(new SettingsPopup(button[0], params), button[0])
            popup.show()

    render: (container, params) ->
        return if params.isEmptyView
        content = renderButton()
        container = $(container)
        container.empty().append(content)
        @_initButton(container, params)


module.exports = {SettingsMenu}
