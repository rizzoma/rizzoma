BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
WaveController = require('./controller').WaveController
BlipController = require('../blip/controller').BlipController
BlipOtConverter = require('../blip/ot_converter').BlipOtConverter
OperationOtConverter = require('../ot/operation_ot_converter').OperationOtConverter
BlipSearchController = require('../blip/search_controller').BlipSearchController
WaveNotificator = require('./notificator').WaveNotificator
IdUtils = require('../utils/id_utils').IdUtils
PlaybackController = require('../playback/controller').PlaybackController

class WaveModule extends BaseModule
    ###
    Модуль предоставляющей API для доступа к волнам и блипам (для отображения одной волны).
    ###
    constructor: (args...) ->
        super(args..., Response)

    createWave: (request, args, callback) ->
        ###
        Создает волну.
        @param request: Request
        ###
        WaveController.createWave(request.user, callback)
    @::v('createWave')

    createWaveWithParticipants: (request, args, callback) ->
        ###
        Создает волну с участниками перечисленными в args.participants
        ###
        waveId = args.waveId
        participants = args.participants
        WaveController.createWaveWithParticipants(waveId, participants, request.user, callback)
    @::v('createWaveWithParticipants', ['waveId(not_null)', 'participants'])

    createWaveByWizard: (request, args, callback) ->
        ###
        Создает волну с заголовком args.title и участниками args.emails
        ###
        emails = args.emails
        title = args.title
        WaveController.createWaveByWizard(request.user, emails, title, null, yes, callback)
    @::v('createWaveByWizard', [])

    getWaveWithBlips: (request, args, callback) ->
        ###
        Возвращает волну и все блипы.
        ###
        waveId = args.waveId
        referalEmailHash = args.referalEmailHash
        user = request.user
        WaveController.getClientWaveWithBlipsByUrl(waveId, user, referalEmailHash, callback)
    @::v('getWaveWithBlips', ['waveId'])

    getPlaybackData: (request, args, callback) ->
        ###
        Возвращает волну и все блипы.
        ###
        waveId = args.waveId
        blipId = args.blipId
        user = request.user
        PlaybackController.getPlaybackData(waveId, blipId, user, callback)
    @::v('getWaveWithBlips', ['waveId(not_null)', 'blipId(not_null)'])

    getBlipForPlayback: (request, args, callback) ->
        ###
        Возвращает волну и все блипы.
        ###
        blipId = args.blipId
        PlaybackController.getBlipForPlayback(blipId, request.user, callback)
    @::v('getBlip', ['blipId(not_null)'])

    subscribeWaveWithBlips: (request, args, callback) ->
        ###
        Подписывается на изменение волны и всех ее блипов.
        в request.versions ожидается объект вида
            wave:
                id: id волны
                version: версия волны
            blips:
                id: version
                ...
        ###
        versions = args.versions
        getListener = (userId, callback) ->
            return (err, op, clientDocId) ->
                clientOp = if err then null else OperationOtConverter.toClient(op, clientDocId)
                callback(new Response(err, clientOp, userId))
        listener = getListener(request.user?.id, request.callback)
        listenerId = "#{request.sessionId}#{request.callId}"
        WaveController.subscribeWaveWithBlips(versions, request.user, listenerId, listener, (err) ->
            callback(err) if err
        )
    @::v('subscribeWaveWithBlips', ['versions'])

    markWaveAsSocialSharing: (request, args, callback) ->
        ###
        Помечаем волну открытой для доступа в соц сетях
        ###
        waveId = args.waveId
        WaveController.markWaveAsSocialSharing(waveId, request.user, callback)
    @::v('markWaveAsSocialSharing', ['waveId(not_null)'])

    addParticipant: (request, args, callback) ->
        ###
        Добавляет участника в волну по каким-то параметрам. В ответ вернет объект добавленного пользователя.
        @param request: Request
        ###
        waveId = args.waveId
        participantId = args.participantId
        role = args.role
        user = request.user
        needNotificate = not args.noNotification
        WaveController.addParticipantEx(waveId, user, participantId, role, needNotificate, callback)
    @::v('addParticipant', ['waveId(not_null)', 'participantId'])

    addParticipants: (request, args, callback) ->
        ###
        Добавляет участников в волну по каким-то параметрам. В ответ вернет объект добавленного пользователя.
        @param request: Request
        ###
        waveId = args.waveId
        participantIds = args.participantIds
        role = args.role
        user = request.user
        needNotificate = not args.noNotification
        WaveController.addParticipantsEx(waveId, user, participantIds, role, needNotificate, callback)
    @::v('addParticipants', ['waveId', 'participantIds'])

    deleteParticipant: (request, args, callback) ->
        ###
        Удаляет участника из волны. В ответ вернет объект добавленного пользователя.
        @param request: Request
        ###
        waveId = args.waveId
        participantId = args.participantId
        WaveController.deleteParticipants(waveId, request.user, [participantId], (err) ->
            callback(err)
        )
    @::v('deleteParticipant', ['waveId(not_null)', 'participantId'])

    deleteParticipants: (request, args, callback) ->
        ###
        Удаляет участников из волны. В ответ вернет объект добавленного пользователя.
        @param request: Request
        ###
        waveId = args.waveId
        participantIds = args.participantIds
        WaveController.deleteParticipants(waveId, request.user, participantIds, (err) ->
            callback(err)
        )
    @::v('deleteParticipants', ['waveId(not_null)', 'participantIds'])

    setShareState: (request, args, callback) ->
        waveId = args.waveId
        sharedState = args.sharedState
        defaultRole = args.defaultRole
        WaveController.setSharedState(waveId, request.user, sharedState, defaultRole, (err) ->
            callback(err)
        )
    @::v('setShareState', ['waveId(not_null)', 'sharedState'])

    closeWave: (request, args, callback, listenerId) ->
        ###
        Закрывает волну.
        @param request: Request
        ###
        waveId = args.waveId
        callId = args.callId
        WaveController.unsubscribeWaveWithBlips(waveId, request.user, listenerId, callback)
    @::v('closeWave', ['waveId(not_null)', 'callId'])

    followWave: (request, args, callback) ->
        waveId = args.waveId
        WaveController.setWaveFollowState(waveId, request.user, true, callback)
    @::v('followWave', ['waveId(not_null)'])

    unfollowWave: (request, args, callback) ->
        waveId = args.waveId
        WaveController.setWaveFollowState(waveId, request.user, false, callback)
    @::v('unfollowWave', ['waveId(not_null)'])

    changeParticipantBlockingState: (request, args, callback) ->
        waveId = args.waveId
        participantId = args.participantId
        state = args.state
        WaveController.changeParticipantBlockingState(waveId, request.user, participantId, state, (err) ->
            callback(err)
        )
    @::v('changeParticipantBlockingState', ['waveId', 'participantId', 'state'])

    changeParticipantRole: (request, args, callback) ->
        waveId = args.waveId
        participantId = args.participantId
        role = args.role
        WaveController.changeParticipantsRole(waveId, request.user, [participantId], role, (err) ->
            callback(err)
        )
    @::v('changeParticipantRole', ['waveId(not_null)', 'participantId', 'role'])

    changeParticipantsRole: (request, args, callback) ->
        waveId = args.waveId
        participantIds = args.participantIds
        role = args.role
        WaveController.changeParticipantsRole(waveId, request.user, participantIds, role, (err) ->
            callback(err)
        )
    @::v('changeParticipantsRole', ['waveId(not_null)', 'participantIds', 'role'])

    updateReaderForAllBlips: (request, args, callback) ->
        waveId = args.waveId
        WaveController.updateReaderForAllBlips(waveId, request.user, (err) ->
            callback(err, if err then null else true)
        )
    @::v('updateReaderForAllBlips', ['waveId(not_null)'])

    createBlip: (request, args, callback) ->
        ###
        Создает блип.
        @param request: Request
        ###
        waveId = args.waveId
        content = args.blipParams.content
        BlipController.createBlip(waveId, request.user, content, callback)
    @::v('createBlip', ['waveId(not_null)', 'blipParams'])

    createCopiedBlip: (request, args, callback) ->
        waveId = args.waveId
        contributors = args.blipParams.contributors
        content = args.blipParams.content
        isFoldedByDefault = args.blipParams.isFoldedByDefault
        sourceBlipId = args.blipParams.sourceBlipId
        BlipController.createCopiedBlip(waveId, request.user, contributors, content, isFoldedByDefault, sourceBlipId, callback)
    @::v('createCopiedBlip', ['waveId(not_null)', 'blipParams'])

    getBlip: (request, args, callback) ->
        ###
        Получает содержимое блипа с версии.
        @param request: Request
        ###
        blipId = args.blipId
        BlipController.getBlip(blipId, request.user, (err, blip) ->
            callback(err, if err then null else BlipOtConverter.toClient(blip, request.user))
        )
    @::v('getBlip', ['blipId(not_null)'])

    subscribeBlip: (request, args, callback, listenerId) ->
        ###
        Подписывает на изменения блипа.
        @param request: Request
        ###
        blipId = args.blipId
        version = args.version
        BlipController.subscribeBlip(blipId, request.user, version, listenerId, (err) ->
            callback(err)
        )
    @::v('subscribeBlip', ['blipId(not_null)', 'version'])

    updateBlipReader: (request, args, callback) ->
        blipId = args.blipId
        BlipController.updateBlipReader(blipId, request.user, (err) ->
            callback(err, if err then null else true)
        )
    @::v('updateBlipReader', ['blipId(not_null)'])

    postOpToBlip: (request, args, callback, listenerId) ->
        blipId = args.blipId
        version = args.version
        op = args.op
        random = args.random
        BlipController.postOp(blipId, request.user, version, op, random, listenerId, callback)
    @::v('postOpToBlip', ['blipId(not_null)', 'version', 'op'])

    closeBlip: (request, args, callback, listenerId) ->
        ###
        Закрывает блип.
        @param request: Request
        ###
        blipId = args.blipId
        BlipController.unsubscribeBlip(blipId, request.user, listenerId, callback)
    @::v('closeBlip', ['blipId(not_null)', 'callId'])

    searchBlipContent: (request, args, callback) ->
        ###
        Обрабатывает запрос на поиск по содержимому блипа.
        В ответе возвращает массив объектов информации о волнах в которых находятся найденные блипы.
        @param request: Request
        ###
        user = request.user
        queryString = args.queryString
        ptagNames = args.ptagNames
        BlipSearchController.searchBlips(user, queryString, ptagNames, args.lastSearchDate, callback)
    @::v('searchBlipContent', ['queryString'])

    searchBlipContentInPublicWaves: (request, args, callback) ->
        ###
        Обрабатывает запрос на поиск по содержимому блипа в только публичных волнах.
        В ответе возвращает массив объектов информации о волнах в которых находятся найденные блипы.
        @param request: Request
        ###
        user = request.user
        queryString = args.queryString
        BlipSearchController.searchPublicBlips(user, queryString, args.lastSearchDate, callback)
    @::v('searchBlipContentInPublicWaves', ['queryString'])

    disconnect: (request, args, callback) ->
        ###
        Обрабатывает отключение клиента.
        @param request: Request
        ###
        OtProcessorFrontend.unsubscribeFromAllChannels(request.sessionId)
        callback(null)
    @::v('disconnect')

    sendAccessRequest: (request, args, callback) ->
        ###
        Запрос на добавление участника в топик
        отправляет письмо автору топика с просьбой добавить туда нового участника
        ###
        user = request.user
        waveId = args.waveId
        WaveNotificator.sendAccessRequest(user, waveId, callback)
    @::v('sendAccessRequest', ['waveId(not_null)'])

module.exports.WaveModule = WaveModule
