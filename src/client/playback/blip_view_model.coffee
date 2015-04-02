{BlipViewModel} = require('../blip')
{PlaybackBlipView} = require('./blip_view')
{PlaybackBlipModel} = require('./blip_model')
{NO_MORE_OPERATIONS, SHOULD_LOAD_NEXT_PART} = require('./constants')
async = require('async')

DIRECTION_FORWARD = 1
DIRECTION_BACK = 2

MODE_ONE_OP = 1
MODE_TO_DATE = 2
MODE_FAST = 3

FAST_MODE_THRESHOLD = 3000

class PlaybackBlipViewModel extends BlipViewModel

    _init: (waveViewModel, @_blipProcessor, blipData, container, parentBlip, isRead, waveId, timestamp, title) ->
        super(waveViewModel, @_blipProcessor, blipData, container, parentBlip, isRead, waveId, timestamp, title)

    __initView: (waveViewModel, blipProcessor, model, timestamp, container, parentBlip, isRead) ->
        @__view = new PlaybackBlipView(waveViewModel, blipProcessor, @, model, timestamp, container, parentBlip, isRead)

    _initModel: (blipData, waveId, isRead, title) ->
        @__model = @_model = new PlaybackBlipModel(blipData, waveId, isRead, title)

    getWave: () ->
        return @_waveViewModel

    executeOneForwardOp: () ->
        @_execute(DIRECTION_FORWARD, MODE_ONE_OP)

    executeOneBackOp: () ->
        @_execute(DIRECTION_BACK, MODE_ONE_OP)

    playToDate: (date) ->
        currentDate = @_model.getCurrentDate()
        return if not currentDate
        if date > currentDate
            @_execute(DIRECTION_FORWARD, MODE_TO_DATE, date)
        else
            @_execute(DIRECTION_BACK, MODE_TO_DATE, date)

    executeFastForward: (date) ->
        @_execute(DIRECTION_FORWARD, MODE_FAST, date)

    executeFastBack: (date) ->
        @_execute(DIRECTION_BACK, MODE_FAST, date)

    _execute: (direction, mode, date) ->
        index = null
        lastOp = null
        lastDate = null
        nextStepErr = null
        isFirstTime = true
        checkFirstTime = () ->
            #Because async is too old and i can't user doWhilst, attempt to update broke riz at all :C
            if isFirstTime
                isFirstTime = false
                return true
            return false
        checkDate = (opDate) ->
            return true if not isFinite(date)
            return if direction == DIRECTION_FORWARD then opDate <= date else opDate >= date
        oneOpModeTest = =>
            return true if checkFirstTime()
            opDate = @_getOpDate(lastOp)
            @_applyToModelAndView(direction, opDate, nextStepErr)
            return false
        toDateModeTest =  =>
            return true if checkFirstTime()
            opDate = @_getOpDate(lastOp)
            continueIteration = checkDate(opDate)
            @_applyToModelAndView(direction, opDate, nextStepErr) if continueIteration
            return continueIteration
        fastModeTest =  =>
            return true if checkFirstTime()
            opDate = @_getOpDate(lastOp)
            continueIteration = checkDate(opDate)
            if lastDate
                delta = Math.abs(opDate-lastDate)
                continueIteration = delta < FAST_MODE_THRESHOLD
            lastDate = opDate
            @_applyToModelAndView(direction, opDate, nextStepErr) if continueIteration
            return continueIteration
        discoverFunc = if direction==DIRECTION_FORWARD then @discoverForward else @discoverBack
        task = (callback) =>
            discoverFunc(index, (err, _nextStepErr, op, newIndex) ->
                return callback(err) if err
                index = newIndex
                lastOp = op
                nextStepErr = _nextStepErr
                callback()
            )
        if mode == MODE_ONE_OP
            async.whilst(oneOpModeTest, task, ->)
        else if mode == MODE_TO_DATE
            async.whilst(toDateModeTest, task, ->)
        else if mode == MODE_FAST
            async.whilst(fastModeTest, task, ->)

    _applyToModelAndView: (direction, date, nextStepErr) ->
        view = @getView()
        rootBlipView = @_waveViewModel.getRootBlipView()
        if direction == DIRECTION_FORWARD
            @_model.forward()
            rootBlipView?.switchBackButtonsState(no)
            view?.switchForwardButtonsState(yes) if nextStepErr == NO_MORE_OPERATIONS
        else
            @_model.back()
            rootBlipView?.switchForwardButtonsState(no)
            view?.switchBackButtonsState(yes) if nextStepErr == NO_MORE_OPERATIONS
        rootBlipView?.setCalendarDate(date)

    _getOpDate: (op) ->
        return new Date(op.meta.ts*1000)

    discoverForward: (index, callback) =>
        callback(@_model.getNextOp(index)...)

    discoverBack: (index, callback) =>
        [err, nextStepErr, op, newIndex] = @_model.getPrevOp(index)
        if not err
            return callback(null, nextStepErr, op, newIndex)
        if err == NO_MORE_OPERATIONS
            return callback(err)
        else if err == SHOULD_LOAD_NEXT_PART
            @_loadNextPart(@_model.getOpsCount(), (err) =>
                return callback(err) if err
                @discoverBack(index, callback)
            )

    _loadNextPart: (offset, callback) =>
        view = @_waveViewModel.getRootBlipView()
        view?.showOperationLoadingSpinner()
        @_blipProcessor.getPlaybackOps(@_model.getServerId(), offset, (err, ops) =>
            view?.hideOperationLoadingSpinner()
            return callback(err) if err
            @_model.appendOps(ops)
            callback()
        )

    getOriginalBlip: () ->
        return @_waveViewModel.getOriginalBlip(@getServerId())

module.exports = {PlaybackBlipViewModel}
