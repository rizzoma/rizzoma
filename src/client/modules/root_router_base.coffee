BaseRouter = require('../../share/base_router').BaseRouter
NetworkRouter = require('./network/network_router').NetworkRouter
utilsDatetimeInit = require('../../share/utils/datetime').init
utilsDatetimeInit('en-Us')
FileModule = require('../file/module').FileModule
{WaveProcessor} = require('../wave/processor')
{UserProcessor} = require('../user/processor')
{TopicsProcessor} = require('../search_panel/topic/processor')
{MentionsProcessor} = require('../search_panel/mention/processor')
{TasksProcessor} = require('../search_panel/task/processor')
{PublicTopicsProcessor} = require('../search_panel/public_topic/processor')
{MarketProcessor} = require('../market_panel/processor')
{ExportProcessor} = require('../export/processor')
{AccountSetupProcessor} = require('../account_setup_wizard/processor')
BrowserEvents = require('../utils/browser_events')

class BaseRootRouter extends BaseRouter
    constructor: (args...) ->
        super(args...)
        module.exports.instance = @
        require('../wave/processor').instance = new WaveProcessor(@)
        require('../user/processor').instance = new UserProcessor(@)

        require('../search_panel/topic/processor').instance = new TopicsProcessor(@)
        require('../search_panel/mention/processor').instance = new MentionsProcessor(@)
        require('../search_panel/task/processor').instance = new TasksProcessor(@)
        require('../search_panel/public_topic/processor').instance = new PublicTopicsProcessor(@)
        require('../market_panel/processor').instance = new MarketProcessor(@)
        require('../export/processor').instance = new ExportProcessor(@)
        require('../account_setup_wizard/processor').instance = new AccountSetupProcessor(@)
        @_addModule 'network', new NetworkRouter @
        @_addModule 'file', new FileModule @

    __blockDangerousEvents: ->
        BrowserEvents.addBlocker(document, BrowserEvents.DRAG_ENTER_EVENT)
        BrowserEvents.addBlocker(document, BrowserEvents.DROP_EVENT)
        document.addEventListener BrowserEvents.DRAG_OVER_EVENT, (e) ->
            BrowserEvents.blockEvent(e)
            e.dataTransfer?.dropEffect = 'none'
        , no

    isConnected: () ->
        return @_moduleRegister.network.isConnected()

module.exports =
    BaseRootRouter: BaseRootRouter
    instance: null
