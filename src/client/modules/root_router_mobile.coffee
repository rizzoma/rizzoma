{BaseRootRouter} = require('./root_router_base')
{BlipProcessor} = require('../blip/processor_mobile')
{TagProcessor} = require('../tag/processor')
{ErrorLogger} = require('../error_logger/module_mobile')

class RootRouter extends BaseRootRouter
    constructor: (args...) ->
        super(args...)
        @__blockDangerousEvents()
        require('../blip/processor_mobile').instance = new BlipProcessor(@)
        errorLogger = new ErrorLogger(@)
        @_addModule('errorLogger', errorLogger)
        require('../error_logger/module_mobile').instance = errorLogger
        @_startApp()

    _startApp: =>
        if window.androidJSInterface
            require('../utils/dom').addClass(document.body, 'from-app')
            try window.androidJSInterface.onPageFinished?()
        Session = require('../session/module').Session
        if window.loggedIn then Session.setAsLoggedIn() else Session.setAsLoggedOut()

        require('../tag/processor').instance = new TagProcessor(@)
        Wave = require('./wave_mobile').Wave
        Navigation = require('./navigation_mobile').Navigation if not window.androidJSInterface?.hasNativeTopicList?()
        PageError = require('./page_error/index_mobile').PageError

        @_addModule 'pageError', new PageError @
        @_addModule 'wave', new Wave @
        @_addModule('navigation', new Navigation(@)) if not window.androidJSInterface?.hasNativeTopicList?()

        tagProcessor = require('../tag/processor').instance = new TagProcessor(@)
        tagProcessor.requestTags()

        require('../account_setup_wizard/processor').instance.checkIsBusinessUser()

module.exports =
    RootRouter: RootRouter
