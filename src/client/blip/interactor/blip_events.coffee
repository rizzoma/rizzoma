BrowserEvents = require('../../utils/browser_events')
{TextLevelParams, LineLevelParams} = require('../../editor/model')

BlipEventTypes =
    CHANGE_MODE: '_changeMode'
    UNDO: '_undo'
    REDO: '_redo'
    MANAGE_LINK: '_manageLink'
    INSERT_FILE: '_insertFile'
    INSERT_IMAGE: '_insertImage'
    MAKE_BOLD: '_makeBold'
    MAKE_ITALIC: '_makeItalic'
    MAKE_UNDERLINED: '_makeUnderlined'
    MAKE_STRUCKTHROUGH: '_makeStruckthrough'
    SET_BG_COLOR: '_setBgColor'
    CLEAR_FORMATTING: '_clearFormatting'
    MAKE_BULLETED: '_makeBulleted'
    MAKE_NUMBERED: '_makeNumbered'
    SET_FOLDED_BY_DEFAULT: '_setFoldedByDefault'
    DELETE: '_delete'
    SEND: '_send'
    INSERT_INLINE_BLIP: '_insertInlineBlip'
    FOLD_ALL: '_foldAll'
    UNFOLD_ALL: '_unfoldAll'
    COPY_BLIP: '_copyBlip'
    PASTE_AT_CURSOR: '_pasteAtCursor'
    PASTE_AS_REPLY: '_pasteAsReply'
    SHOW_BLIP_URL: '_showBlipUrl'
    PLAYBACK: '_playback'

trackMakeTextEvent = (name) -> _gaq.push(['_trackEvent', 'Blip usage', "Make text #{name}"])

toggleTextParam = (interactor, param) ->
    trackMakeTextEvent(param)
    interactor.toggleTextParam(param)


class EventProcessor
    _changeMode: (blipInteractor) ->
        blipInteractor.changeMode()

    _undo: (blipInteractor, args) ->
        ###
        Отменяет последнее сделанное пользователем действие
        ###
        return unless blipInteractor.isEditable()
        if args?.event?.type is BrowserEvents.CLICK_EVENT
            _gaq.push(['_trackEvent', 'Blip usage', 'Undo', 'Button click'])
        else
            _gaq.push(['_trackEvent', 'Blip usage', 'Undo', 'Shortcut'])
        blipInteractor.undo()

    _redo: (blipInteractor, args) ->
        ###
        Повторяет последнее отмененное пользователем действие
        ###
        return unless blipInteractor.isEditable()
        if args?.event?.type is BrowserEvents.CLICK_EVENT
            _gaq.push(['_trackEvent', 'Blip usage', 'Redo', 'Button click'])
        else
            _gaq.push(['_trackEvent', 'Blip usage', 'Redo', 'Shortcut'])
        blipInteractor.redo()

    _manageLink: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Insert link'])
        blipInteractor.manageLink()

    _insertFile: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Insert attach'])
        blipInteractor.insertFile()

    _insertImage: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Insert image'])
        blipInteractor.insertImage()

    _makeBold: (blipInteractor) -> toggleTextParam(blipInteractor, TextLevelParams.BOLD)

    _makeItalic: (blipInteractor) -> toggleTextParam(blipInteractor, TextLevelParams.ITALIC)

    _makeUnderlined: (blipInteractor) -> toggleTextParam(blipInteractor, TextLevelParams.UNDERLINED)

    _makeStruckthrough: (blipInteractor) -> toggleTextParam(blipInteractor, TextLevelParams.STRUCKTHROUGH)

    _setBgColor: (blipInteractor, args) -> blipInteractor.toggleTextParam(TextLevelParams.BG_COLOR, args.value)

    _clearFormatting: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Clear text formatting'])
        blipInteractor.clearFormatting()

    _makeBulleted: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Make text bulleted'])
        blipInteractor.toggleLineParam(LineLevelParams.BULLETED)

    _makeNumbered: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Make text numbered'])
        blipInteractor.toggleLineParam(LineLevelParams.NUMBERED)

    _setFoldedByDefault: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Set always hide']) unless blipInteractor.isFoldedByDefault()
        blipInteractor.toggleFoldedByDefault()

    _delete: (blipInteractor) -> blipInteractor.delete()

    _send: (blipInteractor) -> blipInteractor.sendMessages()

    _insertInlineBlip: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Shortcut'])
        blipInteractor.insertInlineBlip()

    _foldAll: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Hide replies', 'Reply menu'])
        blipInteractor.foldAll()

    _unfoldAll: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Show replies', 'Reply menu'])
        blipInteractor.unfoldAll()

    _copyBlip: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Copy blip'])
        blipInteractor.copyBlip()

    _pasteAsReply: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Paste blip', 'After blip'])
        blipInteractor.pasteAsReply()

    _pasteAtCursor: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Paste blip', 'At cursor'])
        blipInteractor.pasteAtCursor()

    _showBlipUrl: (blipInteractor, args) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Copy blip link'])
        blipInteractor.showBlipUrl(args.event?.target)

    _playback: (blipInteractor) ->
        _gaq.push(['_trackEvent', 'Blip usage', 'Playback'])
        blipInteractor.showPlaybackView()


module.exports =
    BlipEventTypes: BlipEventTypes
    EventProcessor: new EventProcessor()
