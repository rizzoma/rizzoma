{renderCommonForm, renderDecorate, renderVideo} = require('./template')
{ContactPicker} = require('../contact_picker')
{KEY_DOWN_EVENT} = require('../utils/browser_events')
{KEY_ENTER} = require('../utils/key_codes').KeyCodes

class TopicCreatingMaster
    MIN_CONTACTS_HEIGHT = 132
    MAX_CONTACTS_HEIGHT = 440

    constructor: (args...) ->
        @_init(args...)

    _init: (@_container, @_sourceButton, @_waveModule, @_waveProcessor, @_processCreateWaveResponse, @_initCreateButtons, @_renderCreateButtons, @hide_wizard_cookie_name) ->
        $(@_container).append(renderCommonForm())
        @_form = $(@_container).find('.js-ctm')
        @_titleInput = @_form.find('.js-topic-title')
        @_initEvents()
        @setPosition(@_sourceButton)
        @_initVideoBlock()
        contactPickerContainer = $(@_container).find('.js-ctm-contact-picker')[0]
        contactPickerParams =
            contactsSyncStart: (source) -> _gaq.push(['_trackEvent', 'Contacts synchronization', 'Synchronize contacts click', "wizard #{source}"])
            contactsSyncFinish: (source) -> _gaq.push(['_trackEvent', 'Contacts synchronization', 'Successfull synchronization', "wizard #{source}"])
            notificationContainer: $('.js-wave-notifications')
        @_contactPicker = new ContactPicker(contactPickerContainer, @_waveProcessor, contactPickerParams)
        @_contactPicker.updateContacts()
        @_createButtonsContainer = $('.js-create-wave-buttons')
        @show()

    _initEvents: ->
        @_form.find('.js-ctm-create-topic').click(@_createTopic)
        dontShowWizard = @_form.find('.js-ctm-dont-show')
        if $.cookie(@hide_wizard_cookie_name)
            dontShowWizard.attr('checked', 'checked')
        dontShowWizard.on 'change', @_dontShowWizard
        @_titleInput.on KEY_DOWN_EVENT, (e) =>
            return if e.which isnt KEY_ENTER
            @_createTopic()

    _setHeight: =>
        contactsHeight = $(window).height() - 480
        contactsHeight = MIN_CONTACTS_HEIGHT if contactsHeight < MIN_CONTACTS_HEIGHT
        contactsHeight = MAX_CONTACTS_HEIGHT if contactsHeight > MAX_CONTACTS_HEIGHT
        @_contactPicker.setContactsHeight(contactsHeight)

    _initVideoBlock: ->
        @_$videoBlock = @_form.find('.js-wizard-video')
        @_$toggleVideo = @_form.find('.js-toggle-video')
        @_$toggleVideoText = @_form.find('.js-toggle-video-text')
        @_$toggleVideo.on 'click', =>
            if @_$videoBlock.is(':visible')
                @_hideVideoBlock()
                _gaq.push(['_trackEvent', 'Wizard usage', 'Toggle vide', 'Hide video block'])
            else
                @_showVideoBlock()
                _gaq.push(['_trackEvent', 'Wizard usage', 'Toggle vide', 'Show video block'])

    _hideVideoBlock: ->
        @_$videoBlock.empty()
        @_form.width(390)
        @_$toggleVideoText.text('Show video')

    _showVideoBlock: ->
        @_$videoBlock.append(renderVideo())
        @_form.width(915)
        @_$toggleVideoText.text('Hide video')

    _createTopic: =>
        participants = @_contactPicker.getEmails()
        title = @_titleInput.val()
        _gaq.push(['_trackEvent', 'Wizard usage', 'Set topic title']) if title != ''
        _gaq.push(['_trackEvent', 'Topic creation', 'Create topic', 'By wizard', participants.length])
        doCreate = =>
            @_waveProcessor.createWaveByWizard title, participants, (err, waveId) =>
                @_processCreateWaveResponse(err, waveId, doCreate)
            @_waveModule.showTopicCreatingWait()
        doCreate()
        @hide()

    _dontShowWizard: (e) =>
        if $(e.currentTarget).is(':checked')
            $.cookie(@hide_wizard_cookie_name, true, {path: '/topic/', expires: 700})
            @_newTopicBtn.children().remove()
            @_newTopicBtn.addClass('hide-wizard')
            @_newTopicBtn.css('left', "#{@_createButtonsContainer[0].getBoundingClientRect().left + 38}px")
            _gaq.push(['_trackEvent', 'Wizard usage', 'Not show wizard click', 'Not show wizard'])
        else
            $.cookie(@hide_wizard_cookie_name, true, {path: '/topic/', expires: -1})
            @_newTopicBtn.append('<div>New</div>')
            @_newTopicBtn.removeClass('hide-wizard')
            @_newTopicBtn.css('left', "#{@_createButtonsContainer[0].getBoundingClientRect().left}px")
            _gaq.push(['_trackEvent', 'Wizard usage', 'Not show wizard click', 'Show wizard'])
        @_renderCreateButtons()
        @_initCreateButtons()

    setPosition: (@_sourceButton) ->
        offset = $(@_sourceButton).offset()
        if @_form
            @_form.css('top', "#{offset.top - 8}px")
            indent = -20
            @_form.css('left', "#{offset.left + $(@_sourceButton).outerWidth() - indent}px")

    _windowKeyHandler: (e) =>
        return if e.which != 27
        @hide()

    getContainer: ->
        @_form

    hide: =>
        @_ctmOverlay.remove()
        @_newTopicBtn.remove()
        @_hideVideoBlock()
        $(window).off 'keydown', @_windowKeyHandler
        $(window).off 'resize.wizardHeightRecalculate'
        @_form.hide()

    show: ->
        $(document.body).append(renderDecorate(wizardDefault: !$.cookie(@hide_wizard_cookie_name)))
        @_ctmOverlay = $(document.body).find('.js-ctm-overlay')
        offset = $(@_sourceButton).offset()
        @_newTopicBtn = $(document.body).find('.js-ctm-create-button')
        @_newTopicBtn.css('top', "#{offset.top}px")
        leftOffset = offset.left
        leftOffset += 0.5 if $.cookie(@hide_wizard_cookie_name)
        @_newTopicBtn.css('left', "#{leftOffset}px")
        @_ctmOverlay.click @hide
        @_newTopicBtn.click @hide
        $(window).on 'keydown', @_windowKeyHandler
        $(window).on 'resize.wizardHeightRecalculate', =>
            @_setHeight()
        @_setHeight()
        @_form.show()
        @_titleInput.focus()

    destroy: ->
        @_form.remove()

exports.TopicCreatingMaster = TopicCreatingMaster