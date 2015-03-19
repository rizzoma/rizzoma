DomUtils = require('../utils/dom')
{BaseRootRouter} = require('./root_router_base')
{TagProcessor} = require('../tag/processor')
{PingAnalytics} = require('../analytics/ping')
{BlipProcessor} = require('../blip/processor')
{SuccessfulMergePopup} = require('../account_merge/merge_successful_message')
{Collection} = require('../collection/module')
{ActiveTopicControls} = require('../active_topic_controls/module')
{ErrorLogger} = require('../error_logger/module')
{Playback} = require('../playback/module')


class RootRouter extends BaseRootRouter
    ###
    Класс, представляющий корневой роутер. Знает о всех корневых модулях и всех корневых роутерах.
    ###

    constructor: (args...)->
        super args...
        require('../blip/processor').instance = new BlipProcessor(@)
        module.exports.instance = @
        tagProcessor = require('../tag/processor').instance = new TagProcessor(@)
        require('../analytics/ping').instance = new PingAnalytics(@)
        Wave = require('./wave').Wave
        Navigation = require('./navigation').Navigation
        PageError = require('./page_error').PageError

        @_addModule 'pageError', new PageError @
        errorLogger = new ErrorLogger(@)
        @_addModule('errorLogger', errorLogger)
        require('../error_logger/module').instance = errorLogger
        $(document).ready =>
            @__blockDangerousEvents()
            DomUtils.addClass(document.body, 'ie') if require('../utils/browser_support').isIe()
            DomUtils.addClass(document.body, 'gdrive-view') if require('../utils/history_navigation').isGDrive()
            wave = require('./wave').instance = new Wave(@)
            @_addModule('wave', wave)
            @_addModule('navigation', new Navigation @) if window.loggedIn
            collection = new Collection(@)
            require('../collection/module').instance = collection
            @_addModule('collection', collection)
            @_addModule('activeTopicControls', new ActiveTopicControls(@))
            @_addModule('playback', new Playback(@))

            tagProcessor.requestTags()
            if window.showSuccessfulMergePopup
                (new SuccessfulMergePopup()).show()

        # server-side debugging instrument
        window.handle = (method, args) =>
            try
                args = JSON.parse(args)
            catch e
                console.log("Could not parse arguments", args)
                return
            {Request} = require('../../share/communication')
            request = new Request args, (err, res) ->
                console.log("Server response is", err, res)
            method = "network.#{method}"
            console.log("Calling #{method} with args", args)
            @handle(method, request)

module.exports =
    RootRouter: RootRouter
    instance: null
