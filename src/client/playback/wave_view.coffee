{WaveView} = require('../wave/view')
{renderWave} = require('./template')


class PlaybackWaveView extends WaveView

    _init: (waveViewModel, participants) ->
        ###
        @param waveViewModel: WaveViewModel
        @param participants: array, часть ShareJS-документа, отвечающего за участников
        ###
        @_inEditMode = no
        @_isAnonymous = !window.userInfo?.id?
        @_model = waveViewModel.getModel()
        @_editable = no
        @_createDOM(renderWave)
        #@_initWaveHeader(waveViewModel, participants)

        @_reservedHeaderSpace = 0
        @_$wavePanel = $(@container).find('.js-wave-panel')

        @_initEditingMenu()
        #@_updateParticipantsManagement()
        @_initRootBlip(waveViewModel)
        #@_updateReplyButtonState()
        #@_initTips()
        @_initDragScroll()
        waveViewModel.on('waveLoaded', =>
            $(@_waveBlips).on 'scroll', @_setOnScrollMenuPosition
            $(window).on('scroll', @_setOnScrollMenuPosition)
            $(window).on 'resize resizeTopicByResizer', @_resizerRepositionMenu
        )
        @_initBuffer()

#@_$wavePanel.addClass('visible') if not BrowserSupport.isSupported() and not @_isAnonymous
module.exports.PlaybackWaveView = PlaybackWaveView
