IDEVICE = null

class BrowserSupport
    @isWebKit: ->
        !!$.browser.webkit

    @isMozilla: ->
        !!$.browser.mozilla

    @isDesktopChrome: ->
        window.navigator.userAgent.search("Chrome") != -1 and window.navigator.userAgent.search("Mobile") == -1

    @isIEMobile: ->
        !!navigator.userAgent.match(/IEMobile/i)

    @isContentEditableSupported: ->
        return @_isContentEditableSupported if @_isContentEditableSupported?
        t = document.createElement('div')
        @_isContentEditableSupported = t.contentEditable? and (($.browser.webkit and
                parseFloat($.browser.version) - 533 > 0.11) or ($.browser.mozilla and parseInt($.browser.version) >= 9))

    @isTouchSupported: ->
        return @_isTouchSupported if @_isTouchSupported?
        @_isTouchSupported = !!(('ontouchstart' of window) || window.DocumentTouch && document instanceof DocumentTouch)

    @isSupported: ->
        ###
        Возвращает true если в браузере поддерживается редактирование текста.
        Изменяющий! При изменении условий скопируй их в wave.html (этот метод там использовать не получается,
        т.к. там код должен выполниться еще до подключения этого класса)!
        ###
        return yes if BrowserSupport.isContentEditableSupported()
        return yes if BrowserSupport.isTouchSupported()
        no

    @isIDevice: -> IDEVICE ?= navigator.userAgent.search(/iPhone|iPod|iPad/i) > -1

    @isWindows: ->
        navigator.appVersion.indexOf('Win') > -1
        
    @isLinux: ->
        navigator.appVersion.indexOf('Linux')!=-1
    
    @isUnix: ->
        navigator.appVersion.indexOf('X11') > -1
    
    @isMac: ->
        navigator.appVersion.indexOf('Mac') > -1
        
    @getOs: ->
        na = navigator.appVersion
        return 'Linux' if na.indexOf("Linux") > -1
        return 'Unux' if na.indexOf('X11') > -1
        return 'Mac' if na.indexOf('Mac') > -1
        return 'Windows' if na.indexOf('Win') > -1

module.exports = BrowserSupport
