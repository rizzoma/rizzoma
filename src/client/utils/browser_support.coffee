class BrowserSupport
    @isWebKit: ->
        !!$.browser.webkit

    @isMozilla: ->
        !!$.browser.mozilla

    @isIe: ->
        !!$.browser.msie

    @isDesktopChrome: ->
        window.navigator.userAgent.search("Chrome") != -1 and window.navigator.userAgent.search("Mobile") == -1

    @isSupported: ->
        ###
        Возвращает true если в браузере поддерживается редактирование текста.
        Изменяющий! При изменении условий скопируй их в wave.html (этот метод там использовать не получается,
        т.к. там код должен выполниться еще до подключения этого класса)!
        ###
        test = document.createElement('div')
        return no if not test.contentEditable?
        return yes if $.browser.webkit or (($.browser.mozilla or $.browser.msie) and parseInt($.browser.version) >= 9)
        no
    
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
