ck = window.CoffeeKup

errorTmpl = ->
    ###
    Шаблон ошибки в волне
    ###
    div '.set-3d', ''
    img '', {src: '/s/img/error-icon.png', alt: 'Error'}
    div '.wave-error-text', ->
        if @error.logId
            text h("#{@error.message}")
            br '', ''
            text h("Code: #{@error.logId}")
        else
            text h("#{@error.message}")
    span '.js-error-close-button.error-close-icon', ''
    div '.clearer', ''

warningTmpl = ->
    ###
    Шаблон предупреждения в волне
    ###
    div '.set-3d', ''
    img '', {src: '/s/img/warning-icon.png', alt: 'Warning'}
    div '.wave-warning-text', ->
        text h("#{@message}")
    span '.js-warning-close-button.warning-close-icon', ''
    div '.clearer', ''

anonymousTmpl = ->
    ###
    Шаблон предупреждения о необходимости авторизоваться
    ###
    div ".js-anonymous-notification-container.anonymous-notification-container", ->
        div '.notification-overlay', ''
        div '.js-notification-block.notification-block', ->
            div '.sign-in-block', ->
                for cta in @callToAction
                    div '.call-to-action', cta
                div '.buttons-container', ->
                    a '.js-google-login-link.google-login-link', {
                        href: "/auth/google/?url=#{encodeURIComponent(@redirectUrl)}",
                        title: 'Sign in with Google',
                        onclick: "_gaq.push(['_trackEvent', 'Authorization', 'Authorize with Google click', 'Topic']); _gaq.push(['_trackPageview', '/authorization/google/']);"
                    }
                    a '.js-facebook-login-link.facebook-login-link', {
                        href: "/auth/facebook/?url=#{encodeURIComponent(@redirectUrl)}",
                        title: 'Sign in with Facebook',
                        onclick: "_gaq.push(['_trackEvent', 'Authorization', 'Authorize with Facebook click', 'Topic']); _gaq.push(['_trackPageview', '/authorization/facebook/']);"
                    }
                div '.bottom-corner', ->
                    div '', ''
            div '.bottom-caption', ->
                div '.slogan', '"Build your group mind"'
                div '.sign', 'Rizzoma Squad'

exports.renderError = ck.compile(errorTmpl)

exports.renderWarning = ck.compile(warningTmpl)
    
exports.renderAnonymousNotification = ck.compile(anonymousTmpl)