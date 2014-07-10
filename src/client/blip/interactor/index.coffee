{Interactable} = require('../../utils/interactable')
{BlipUndoRedo} = require('../undoredo')
{EventProcessor} = require('./blip_events')
{KeyInteractor} = require('./key_interactor')
{TextLevelParams, LineLevelParams} = require('../../editor/model')
{PopupContent, popup} = require('../../popup')
{TEXT_MODIFIERS} = require('../../menu')

# TODO: it shouldn't be there
{renderCopyBlipLinkPopup} = require('../menu/template')

class BlipEventInteractor
    constructor: (@_blipViewModel, @_blipView) ->  # TODO: we definitely need only one of them
        @_editable = no
        @_interactables = []
        @_editor = @_blipView.getEditor()
        @_undoRedo = new BlipUndoRedo(@_blipViewModel, @_blipView)  # TODO: we definitely need only one of them
        @_keyInteractor = new KeyInteractor(@_blipView.getContainer())
        @_textModifiers = {} # TODO: maybe it should be inside editor interactor
        @_attach(@_keyInteractor)

    _handleEvent: (event) =>
        if not EventProcessor[event.type]?
            console.trace?()
            return console.warn("Event '#{event.type}' is not supported")
        try
            EventProcessor[event.type](@, event.args)
        catch e
            console.error('Failed to handle event', e)

    _attach: (interactable) ->
        return if @_interactables.indexOf(interactable) >= 0
        interactable.on(Interactable.EVENT, @_handleEvent)
        @_interactables.push(interactable)

    _detach: (interactable) ->
        return if (index = @_interactables.indexOf(interactable)) < 0
        @_interactables[index].removeListener(Interactable.EVENT, @_handleEvent)
        @_interactables.splice(index, 1)

    _attachMenu: (blipMenu, placeHolder, params) ->
        return if @_blipMenu
        @_keyInteractor.attach() # TODO: do not detach when keyInteractor -> editorInteractor
        placeHolder.appendChild(blipMenu.getContainer())
        blipMenu.reset(params)
        @_attach(blipMenu)
        @_blipMenu = blipMenu
        @_updateEditingModifiers()
        @_updateUndoRedoState()

    _detachMenu: ->
        @_keyInteractor.detach() # TODO: do not detach when keyInteractor -> editorInteractor
        return unless @_blipMenu
        menuElement = @_blipMenu.getContainer()
        menuElement.parentNode?.removeChild(menuElement)
        @_detach(@_blipMenu)
        @_blipMenu?.detach()
        delete @_blipMenu

    _updateUndoRedoState: ->
        return unless @_blipMenu
        @_blipMenu.setUndoButtonDisabled(!@_undoRedo.hasUndoOps())
        @_blipMenu.setRedoButtonDisabled(!@_undoRedo.hasRedoOps())

    _cursorInText: ->
        # TODO: remove it
        @_blipViewModel.getWaveViewModel().getView().cursorIsInText()

    _setEditable: (@_editable) ->
        if @_editable
            @_blipMenu?.setEditMode()
            @_keyInteractor.setEditModeKeyHandlers()
        else
            @_blipMenu?.setReadMode()
            @_keyInteractor.setReadModeKeyHandlers()

    _updateLineButtons: ->
        @_blipMenu?.setLineParams(@_editor.getLineParams())

    _updateTextButtons: ->
        @_blipMenu?.setTextParams(@_textModifiers)

    _copyEditingModifiers: (textParams) ->
        for key of TEXT_MODIFIERS
            if textParams[key]?
                @_textModifiers[key] = textParams[key]
            else
                @_textModifiers[key] = null

    _updateEditingModifiers: ->
        @_updateLineButtons()
        @_copyEditingModifiers(@_editor.getTextParams())
        @_updateTextButtons()

    _toggleLineParam: (name) ->
        param = @_editor.getLineParams()[name]
        @_editor.setRangeLineParam(name, if param? then null else 0)
        @_updateLineButtons()

    _toggleTextParam: (name, value) ->
        if value is undefined
            if @_textModifiers[name]
                value = null
            else
                value = true
        @_textModifiers[name] = value
        @_updateTextButtons()
        return unless (range = @_editor.getRange())
        if range.collapsed
            @_editor.setEditingModifiers(@_textModifiers)
        else
            @_editor.setRangeTextParam(name, @_textModifiers[name])

    _clearFormatting: ->
        @_copyEditingModifiers({})
        @_updateTextButtons()
        return unless (range = @_editor.getRange())
        if range.collapsed
            @_editor.setEditingModifiers(@_textModifiers)
        else
            @_editor.clearSelectedTextFormatting()

    _finishUndoRedoProcess: ->
        @_updateUndoRedoState()
        @_updateEditingModifiers()

    getBlip: -> @_blipView

    updateUndoRedoState: ->
        @_updateUndoRedoState()

    attachMenu: (blipMenu, placeHolder, params) -> @_attachMenu(blipMenu, placeHolder, params)

    detachMenu: -> @_detachMenu()

    changeMode: -> @_blipView.setEditable(!@_editable)

    setEditableMode: (editable) -> @_setEditable(editable)

    isEditable: -> @_editable

    undo: ->
        @_undoRedo.undo()
        @_finishUndoRedoProcess()

    redo: ->
        @_undoRedo.redo()
        @_finishUndoRedoProcess()

    manageLink: ->
        return if not @_cursorInText()
        @_blipView.getEditor().openLinkEditor()

    insertFile: -> @_editor.openUploadForm(no)

    insertImage: -> @_editor.openUploadForm(yes)

    toggleLineParam: (name) ->
        # TODO: check line (name) param
        @_toggleLineParam(name)

    toggleTextParam: (name, value) ->
        # TODO: check text (name) param
        @_toggleTextParam(name, value)

    clearFormatting: -> @_clearFormatting()

    updateEditingModifiers: -> @_updateEditingModifiers()

    toggleFoldedByDefault: ->
        model = @_blipViewModel.getModel()
        return unless model
        folded = model.isFoldedByDefault()
        @_blipView.fold() unless folded
        model.setIsFoldedByDefault(!folded)
        @_blipMenu?.setFoldedByDefault(!folded)

    updateFoldedByDefault: (folded) ->
        @_blipMenu?.setFoldedByDefault(folded)

    isFoldedByDefault: -> @_blipViewModel.getModel()?.isFoldedByDefault()

    delete: -> @_blipView.removeWithConfirm()

    sendMessages: ->
        @_blipMenu.updateSendButton('Sending…')
        @_blipView.sendMessages (err) =>
            return unless @_blipMenu
            return @_blipMenu.updateSendButton('Error sending') if err
            @_blipMenu.updateSendButton('Sent')

    insertInlineBlip: ->
        return if not @_cursorInText()
        @_blipView.initInsertInlineBlip()

    foldAll: -> @_blipView.foldAllChildBlips()

    unfoldAll: -> @_blipView.unfoldAllChildBlips()

    copyBlip: ->
        @_blipView.renderRecursively() # TODO: really?
        @_blipView.getParent().getEditor().copyElementToBuffer(@_blipView.getContainer())

    pasteAsReply: ->
        # TODO: bad call
        @_blipView.getParent().getEditor().pasteBlipFromBufferAfter(@_blipViewModel.getView().getContainer())

    pasteAtCursor: -> @_editor.pasteBlipFromBufferToCursor()

    showBlipUrl: (target) ->
        return if popup.getContainer()
        copyBlipLinkPopup = new CopyBlipLinkPopup({url: @_blipView.getUrl()})
        popup.render(copyBlipLinkPopup, target)
        popup.show()

    setFoldable: (foldable) -> @_blipMenu?.setFoldable(foldable)

    setSendable: (sendable) -> @_blipMenu?.setSendable(sendable)

    setLastSent: (lastSent, lastSender) -> @_blipMenu?.setLastSent(lastSent, lastSender)

    setCanEdit: (canEdit) -> @_blipMenu?.setCanEdit(canEdit)

    enableIdDependantButtons: -> @_blipMenu?.enableIdDependantButtons()

    attach: (interactable) -> @_attach(interactable)

    detach: (interactable) -> @_detach(interactable)

    destroy: ->
        @_detachMenu()
        delete @_blipViewModel
        delete @_blipView
        delete @_editor
        delete @_blipMenu
        @_undoRedo.destroy()
        delete @_undoRedo
        @_keyInteractor.destroy()
        delete @_keyInteractor
        for interactable in @_interactables
            interactable.removeListener(Interactable.EVENT, @_handleEvent)
        delete @_interactables

# TODO: move it out this module
class CopyBlipLinkPopup extends PopupContent
    constructor: (params) ->
        @_container = document.createElement('span')
        @_render(params)

    _render: (params) ->
        ###
        Рендерим блоки для копирования ссылки
        ###
        $(@_container).append(renderCopyBlipLinkPopup(params))
        @_selectInputText()

    _selectInputText: ->
        blipUrl = $(@_container).find('.js-blip-link')
        setTimeout ->
            blipUrl.select()
        , 0
        blipUrl.bind 'click', =>
            blipUrl.select()

    destroy: ->
        $(@_container).remove()
        @_container = null

    getContainer: ->
        return @_container

module.exports = {BlipEventInteractor}
