###
@package: volna
@autor: quark, 2011
###

BaseRouter = require('../../share/base_router').BaseRouter

WaveModule = require('../wave/module').WaveModule
MessageModule = require('../message/module').MessageModule
GTagModule = require('../gtag/module').GTagModule
FileModule = require('../file/module').FileModule
TaskModule = require('../task/module').TaskModule
UserModule = require('../user/module').UserModule
ExportModule = require('../export/module').ExportModule
StoreModule = require('../store/module').StoreModule
TeamModule = require('../team/module').TeamModule
MessagingModule = require('../messaging/module').MessagingModule
PlaybackModule = require('../playback/module').PlaybackModule

class RootRouter extends BaseRouter
    ###
    Класс, представляющий рутовый роутер. Знает о всех корневых модулях и всех корневых роутерах.
    ###
    constructor: (args...)->
        super(args...)
        @_addModule('wave', new WaveModule(@))
        @_addModule('message', new MessageModule(@))
        @_addModule('gtag', new GTagModule(@))
        @_addModule('file', new FileModule(@))
        @_addModule('task', new TaskModule(@))
        @_addModule('user', new UserModule(@))
        @_addModule('export', new ExportModule(@))
        @_addModule('store', new StoreModule(@))
        @_addModule('team', new TeamModule(@))
        @_addModule('messaging', new MessagingModule(@))
        @_addModule('playback', new PlaybackModule(@))

module.exports = RootRouter
