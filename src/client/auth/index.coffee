isEmailRe = /^[-a-z0-9!#$%&'*+/=?^_`{|}~]+(?:\.[-a-z0-9!#$%&'*+/=?^_`{|}~]+)*@(?:[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?\.)*(?:aero|arpa|asia|biz|cat|com|coop|edu|gov|info|int|jobs|mil|mobi|museum|name|net|org|pro|tel|travel|[a-z][a-z])$/i
isEmail = (str) ->
    isEmailRe.test(str)

class Panel
    ###
    базовая панель
    ###
    constructor: (@_errors, url) ->
        # форма
        @_form = @_getForm()
        @_form.find('input').placeholder?()
        @_createNoRobotsField()
        @_submitBtn = null
        @_successMsg = @_form.find(".js-success-msg")
        @_initAjaxForm()
        @_initNext(url)

    _initNext: (url) ->
        ###
        Заменяет на ссылках url для редиректа после авторизации
        @param url относительный url, должен начинаться со слеша
        ###
        @_next = if not url or not url.match(/^\//) then '/topic/' else url
        @_form.find(".js-google-login-link")?.attr 'href', "#{@_getUrlPrefix()}/auth/google/?url=#{encodeURIComponent(@_next)}"
        @_form.find('.js-facebook-login-link')?.attr 'href', "#{@_getUrlPrefix()}/auth/facebook/?url=#{encodeURIComponent(@_next)}"

    setNext: (url) ->
        ###
        Устанавливает редирект после логина
        ###
        @_initNext(url)

    show: () ->
        ###
        действия при показывании панели
        ###
        @_hideError()
        @_showFormFields()
        @_hideSuccessMessage()
        @_form.removeClass('hidden')

    hide: () ->
        ###
        действия при скрывании панели
        ###
        @_form.addClass('hidden')

    _createNoRobotsField: () ->
        @_form.append('<input type="hidden" name="no_robots" value="no robots here"/>')

    _getForm: () ->
        ###
        контейнер формы
        ###
        return null

    _initAjaxForm: () ->
        ###
        инициализируем отправку формы
        ###
        @_form.ajaxForm({
            url: @_getUrlPrefix() + @_getFormUrl()
            dataType: "json"
            beforeSubmit: @_beforeSubmit
            success: @_onSuccess
            error: @_onError
        })

    _showSuccessMessage: (message) ->
        ###
        показывает сообщение если все получилось
        ###
        @_successMsg?.text(message)
        @_successMsg?.removeClass('hidden')

    _hideSuccessMessage: () ->
        @_successMsg?.addClass('hidden')

    _showError: (message, field=null, showBefore=false) ->
        ###
        показывает сообщение об ошибке
        ###
        @_errors.showError(message, field, showBefore)

    _hideError: () =>
        @_errors.hideError()

    _getUrlPrefix: () ->
        ###
        https и имя хоста, если скрипт запущен на Риззоме,
        Пустая строка, если запущено на dev-сервере.
        ###
        hostname = document.location.hostname
        return "https://#{hostname}" if /rizzoma\.com$/.test(hostname)
        return ""

    _getFormUrl: () ->
        ###
        url на который постится форма
        должен переопределяться в потомках
        ###
        throw new Error("Not implemented")

    _beforeSubmit: (formData, form, options) ->
        ###
        Валидирует форму перед отправкой
        должно переропределеяться в потомках
        @return: bool - если вернуть false то форма не отправится
        ###
        @_hideError()
        @_submitBtn.addClass('active')
        return true

    _onError: (err) =>
        ###
        Чего делать когда пришла внутренняя ошибка сервера или таймаут
        ###
        @_submitBtn.removeClass('active')
        @_showError("Internal Server Error")

    _onSuccess: (data, statusText, xhr, form) =>
        ###
        Чего делать когда все хорошо
        ###
        @_submitBtn.removeClass('active')

    _validateUsernameField: (usernameField, showBefore=false) ->
        username = @_usernameField.val().trim()
        if not username
            @_showError("Empty email", usernameField, showBefore)
            return false
        if not isEmail(username)
            @_showError("#{username} is not a valid email", usernameField, showBefore)
            return false
        return true

    _validatePasswordField: (passwordField) ->
        password = @_passwordField.val().trim()
        if not password
            @_showError("Empty password", passwordField)
            return false
        return true

    _removeSubmitBtnActiveState: () =>
        setTimeout(() =>
            @_submitBtn.removeClass('active')
        , 0)

    _showFormFields: () ->


class SignInPanel extends Panel
    ###
    панель входа в систему
    ###
    constructor: (errors, url) ->
        super(errors, url)
        @_showSignUpFormLink = @_form.find(".js-show-sign-up-form-link")
        @_usernameField = @_form.find("[name=username]")
        @_passwordField = @_form.find("[name=password]")
        @_showForgotPasswordFormLink = $(".js-show-forgot-password-form-link")
        @_submitBtn = @_form.find("[type=submit]")
        @_submitBtn.on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Sign in with password', window.location.pathname]);)
        @_form.find(".js-google-login-link").on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Authorize with Google click', window.location.pathname]);)
        @_form.find(".js-facebook-login-link").on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Authorize with Facebook click', window.location.pathname]);)

    getShowSignUpFormLink: -> @_showSignUpFormLink

    getShowForgotPasswordFormLink: -> @_showForgotPasswordFormLink

    _getForm: () -> $("#sign-in-form")

    _getFormUrl: () => "/auth/password/json/"

    _beforeSubmit: (formData, form, options) =>
        super(formData, form, options)
        if not @_validateUsernameField(@_usernameField)
            @_removeSubmitBtnActiveState()
            return false
        if not @_validatePasswordField(@_passwordField)
            @_removeSubmitBtnActiveState()
            return false
        return true

    _getURLParameter: (name, url=location.search) ->
        return decodeURI(
            (RegExp(name + '=' + '(.+?)(&|$)').exec(url) or [null,null])[1]
        )

    _onSuccess: (data, statusText, xhr, form) =>
        super(data, statusText, xhr, form)
        field = null
        if data.error
            switch data.error.code
                when "empty_email" then field = @_usernameField
                when "invalid_email" then field = @_usernameField
                when "user_not_found" then field = @_usernameField
                when "user_not_confirmed" then field = @_usernameField
                when "empty_pasword" then field = @_usernameField
                when "wrong_password" then field = @_passwordField
            @_showError(data.error.message, field)
        else
            document.location.href = @_next

    _showFormFields: () ->


class SignUpPanel extends Panel
    ###
    панель регистрации
    ###
    constructor: (errors, url) ->
        super(errors, url)
        @_showSignInFormLink = @_form.find(".js-show-sign-in-form-link")
        @_usernameField = @_form.find("[name=username]")
        @_nameField = @_form.find("[name=name]")
        @_passwordField = @_form.find("[name=password]")
        @_submitBtn = @_form.find("[type=submit]")
        @_submitBtn.on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Sign up with password', window.location.pathname]);)
        @_form.find(".js-google-login-link").on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Authorize with Google click', window.location.pathname]);)
        @_form.find(".js-facebook-login-link").on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Authorize with Facebook click', window.location.pathname]);)

    getShowSignInFormLink: -> @_showSignInFormLink

    _getForm: () -> $("#sign-up-form")

    _getFormUrl: () => "/auth/register/json/"

    _beforeSubmit: (formData, form, options) =>
        super(formData, form, options)
        if not @_nameField.val().trim()
            @_showError("Empty name", @_nameField)
            @_removeSubmitBtnActiveState()
            return false
        if not @_validateUsernameField(@_usernameField)
            @_removeSubmitBtnActiveState()
            return false
        if not @_validatePasswordField(@_passwordField)
            @_removeSubmitBtnActiveState()
            return false
        return true

    _onSuccess: (data, statusText, xhr, form) =>
        super(data, statusText, xhr, form)
        field = null
        if data.error
            switch data.error.code
                when "empty_name" then field = @_nameField
                when "empty_email" then field = @_usernameField
                when "invalid_email" then field = @_usernameField
                when "already_registered" then field = @_usernameField
                when "user_not_found" then field = @_usernameField
                when "user_not_confirmed" then field = @_usernameField
                when "empty_pasword" then field = @_usernameField
                when "short_password" then field = @_usernameField
                when "wrong_password" then field = @_passwordField
            @_showError(data.error.message, field)
        else
            @_hideFormFields()
            @_showSuccessMessage("We have sent you an email with instructions for completing your registration")

    _hideFormFields: () ->
        @_usernameField.addClass("hidden")
        @_nameField.addClass("hidden")
        @_passwordField.addClass("hidden")
        @_submitBtn.addClass("hidden")

    _showFormFields: () ->
        @_usernameField.removeClass("hidden")
        @_nameField.removeClass("hidden")
        @_passwordField.removeClass("hidden")
        @_submitBtn.removeClass("hidden")



class ForgotPasswordPanel extends Panel
    ###
    панель для напоминания пароля
    ###
    constructor: (errors) ->
        super(errors)
        @_showSignInFormLink = @_form.find(".js-show-sign-in-form-link")
        @_usernameField = @_form.find("[name=username]")
        @_submitBtn = @_form.find("[type=submit]")
        @_submitBtn.on('click', ->
            _gaq.push(['_trackEvent', 'Authorization', 'Reset password', window.location.pathname]);)

    getShowSignInFormLink: -> @_showSignInFormLink

    _getForm: () -> $("#forgot-password-form")

    _getFormUrl: () => "/auth/forgot_password/json/"

    _beforeSubmit: (formData, form, options) =>
        super(formData, form, options)
        if not @_validateUsernameField(@_usernameField, true)
            @_removeSubmitBtnActiveState()
            return false

    _onSuccess: (data, statusText, xhr, form) =>
        super(data, statusText, xhr, form)
        field = null
        if data.error
            switch data.error.code
                when "empty_email" then field = @_usernameField
                when "invalid_email" then field = @_usernameField
                when "user_not_found" then field = @_usernameField
                when "user_not_confirmed" then field = @_usernameField
            @_showError(data.error.message, field, true)
        else
            @_hideFormFields()
            @_showSuccessMessage("Reset link has been sent successfully. Check your email")

    _hideFormFields: () ->
        @_usernameField.addClass("hidden")
        @_submitBtn.addClass("hidden")

    _showFormFields: () ->
        @_usernameField.removeClass("hidden")
        @_submitBtn.removeClass("hidden")



class ErrorContainer
    ###
    Контейнер для ошибок
    ###
    constructor: () ->
        @_errors = $('.js-errors')
        @_erroredField = null
        @_errors.find(':first-child').click((e) =>
            @hideError()
        )

    showError: (message, field=null, hideBefore=false) ->
        ###
        показывает сообщение об ошибке
        ###
        @_errors.removeClass("hide-before")
        @_erroredField?.removeClass("error-border")
        @_errors.removeClass("hidden")
        @_errors.find(".js-msg").text(message)
        if field
            field.addClass("error-border")
            field.focus()
            @_erroredField = field
        @_errors.addClass("hide-before") if hideBefore

    hideError: () ->
        @_errors.addClass("hidden")
        @_errors.removeClass("hide-before")
        @_erroredField?.removeClass("error-border")


class AuthDialog
    ###
    Диалог логина в риззому
    если closable навешивает показ формы на элементы с классом .js-enter-rizzoma-btn
    ###

    constructor: () ->
        @_authDialog = null
        @_closeAuthDialogBtn = null
        @_panels = {}
        @_inited = false
        @_errors = null

    initAndShow: (closable=true, url=null, callback) ->
        ###
        @param closable: bool - навешивать или нет события закрывания диалога
        @param url: string - куда редиректить после авторизации
        ###
        return window.androidJSInterface.onLogout() if window.androidJSInterface
        return @_showAsync(callback) if @_inited
        @init closable, url, () =>
            @_showAsync(callback)

    init: (closable=true, url=null, callback) ->
        ###
        @param closable: bool - навешивать или нет события закрывания диалога
        @param url: string - куда редиректить после авторизации
        ###
        return callback?(null) if @_inited
        $(document).ready(() =>
            @_authDialog = $(".js-auth-dialog")
            if closable
                @_initCloseAuthDialog()
                @_initShowAuthDialog()
            @_initErrors()
            @_initPanels(url)
            @_inited = true
            callback?(null)
        )

    _onClose: (e) =>
        return if e.target != e.delegateTarget
        @_authDialog.addClass('hidden')
        e.preventDefault()
        e.stopPropagation()

    show: () ->
        @_showPanel(@_panels.signInPanel)
        @_authDialog.removeClass('hidden')

    visible: () ->
        return !!@_authDialog and !@_authDialog.hasClass('hidden')

    setNext: (url) ->
        ###
        Устанавливает редирект после логина
        @param url относительный url, должен начинаться со слеша
        ###
        for name, panel of @_panels
            panel.setNext(url)

    _onShowBtn: (e) =>
        ###
        по нажатию на кнопку показа
        ###
        next = $(e.target).attr("data-redirect-url")
        @setNext(next) if next
        @show()
        e.preventDefault()
        e.stopPropagation()

    _showAsync: (callback) ->
        @show()
        callback?(null)

    _initErrors: () ->
        @_errors = new ErrorContainer()

    _initPanels: (url) ->
        ###
        @param url: string - куда редиректить после авторизации
        ###
        @_panels.signInPanel = new SignInPanel(@_errors, url)
        @_panels.signUpPanel = new SignUpPanel(@_errors, url)
        @_panels.forgotPasswordPanel = new ForgotPasswordPanel(@_errors)
        @_initTogglePanels()

    _showPanel: (showedPanel) ->
        for name, panel of @_panels
            if panel == showedPanel then panel.show() else panel.hide()

    _getOnShowPanel: (panel) ->
        return (e) =>
            @_showPanel(panel)
            e.preventDefault()
            e.stopPropagation()

    _initTogglePanels: () ->
        @_panels.signInPanel.getShowSignUpFormLink().click(@_getOnShowPanel(@_panels.signUpPanel))
        @_panels.signInPanel.getShowForgotPasswordFormLink().click(@_getOnShowPanel(@_panels.forgotPasswordPanel))
        @_panels.signUpPanel.getShowSignInFormLink().click(@_getOnShowPanel(@_panels.signInPanel))
        @_panels.forgotPasswordPanel.getShowSignInFormLink().click(@_getOnShowPanel(@_panels.signInPanel))

    _initCloseAuthDialog: () ->
        @_closeAuthDialogBtn = $(".js-close-auth-dialog-btn")
        @_closeAuthDialogBtn.removeClass('hidden')
        @_closeAuthDialogBtn.click(@_onClose)
        @_authDialog.click(@_onClose)

    _initShowAuthDialog: () ->
        ###
        навешивает показ формы на элементы с классом .js-enter-rizzoma-btn
        ###
        showBtn = $(".js-enter-rizzoma-btn")
        showBtn.click(@_onShowBtn)


window.AuthDialog = new AuthDialog()
