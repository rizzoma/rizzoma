BrowserSupport = require('../utils/browser_support')
{ChromeAppPopup} = require('../chrome_app_popup')
{CrowdPopup} = require('../crowd_popup')
{Introduce} = require('../introduce')
{popup, PopupContent} = require('../popup')

ck = window.CoffeeKup

buttonTmpl = ->
    div '.js-help-button.help-button', ->
        div '.pict.help-pict', ''
        text 'Help'
        div '.js-help-placeholder', ''

popupTmpl = ->
    div '.js-help-menu.help-menu', ->
        a {href: 'https://rizzoma.zendesk.com', onclick: 'try {Zenbox.show(); return false;} catch(e){}', target: '_blank'}, 'Support'
        a '.js-reopen-help-page', {href: '#'}, 'Guide'
        a {href: '/help-center-video.html?from=helpblock', target: '_blank'}, 'Video'
        a {href: '/help-center-faq.html?from=helpblock', target: '_blank'}, 'FAQ'
        a {href: 'http://blog.rizzoma.com/?from=helpblock', target: '_blank'}, 'Blog'
        if @isDesktopChrome
            a '.js-chrome-app', {href: '#', title: 'Install our Chrome application'}, 'Apps'
        a '.js-open-crowd-popup', {href: '#'}, 'Crowd'
        a '.js-show-topic-tip.show-topic-tip', {href: '#', title: 'Show random tips in opened topic'}, 'Show tips'
        a {href: '/about-security.html?from=help_menu', title: 'Security - updated 30 April 2013', target: '_blank'}, 'Security'

renderButton = ck.compile(buttonTmpl)
renderPopup = ck.compile(popupTmpl)

zenboxInitialized = false

class HelpPopup extends PopupContent
    
    constructor: ->
        container = $(renderPopup(
            isDesktopChrome: BrowserSupport.isDesktopChrome()
        ))
        @_container = container[0]
        @_initMenu(container)
        @_initZenboxWidget(container)
        @_initChromeAppPopup(container)
        @_initGuidePopup(container)
        @_initCrowdPopup(container)
        @_initShowTipsButton(container)

    _initMenu: (container) ->
        container.on 'click', 'a', (e) ->
            _gaq.push(['_trackEvent', 'Help block', 'Link click', e.target.textContent])
            popup.hide()

    _initZenboxWidget: (container) ->
        Zenbox.init({dropboxID: "20194027",url: "https://rizzoma.zendesk.com",tabTooltip: "Ask Us",tabImageURL: "https://assets.zendesk.com/external/zenbox/images/tab_ask_us.png",tabColor: "#40E0D0",tabPosition: "Left",hide_tab:"true",}) if Zenbox? and !zenboxInitialized
        zenboxInitialized = true

    _initChromeAppPopup: (container) ->
        return if not BrowserSupport.isDesktopChrome()
        button = container.find('.js-chrome-app')
        button.click (e) ->
            e.preventDefault()
            new ChromeAppPopup()

    _initGuidePopup: (container) ->
        button = container.find('.js-reopen-help-page')
        button.click (e) ->
            e.preventDefault()
            _gaq.push(['_trackEvent', 'Introduce page', 'Reopen introduce page'])
            setTimeout(->
                new Introduce()
            , 200)

    _initCrowdPopup: (container) ->
        button = container.find('.js-open-crowd-popup')
        button.click (e) ->
            _gaq.push(['_trackEvent', 'Crowd popup', 'show', 'help block'])
            e.preventDefault()
            new CrowdPopup()

    _initShowTipsButton: (container) ->
        button = container.find('.js-show-topic-tip')
        processor = require('../wave/processor').instance
        if not processor
            button.addClass('hidden')
            return
        button.click (e) ->
            e.preventDefault()
            window.getSelection()?.removeAllRanges()
            processor.showTips()

    destroy: ->

    getContainer: ->
        return @_container


class HelpMenu

    _initButton: (container) ->
        button = container.find('.js-help-button')
        button.click ->
            _gaq.push(['_trackEvent', 'Help block', 'Open help block'])
            popup.hide()
            popup.render(new HelpPopup(), button.find('.js-help-placeholder')[0])
            popup.addExtendedClass('help-menu-popup')
            popup.show()
    
    render: (container) ->
        content = renderButton()
        container = $(container)
        container.empty().append(content)
        @_initButton(container)


module.exports = {HelpMenu}
