DomUtils = require('../../utils/dom')
{compareContactsByNameAndEmail, getContactSources} = require('../../user/utils')
{KeyCodes} = require('../../utils/key_codes')
contactsConstants = require('../../../share/contacts/constants')
ck = window.CoffeeKup

formTmpl = ->
    div '.internal-container', ->
        div '.input-email-title', ->
            text 'Add new'
            select '.js-add-select.add-button-select', ->
                for {id, name} in @addButtons
                    option {value: id}, name
        div '.input-email-container', ->
            input '.js-input-email.input-email', {type: "text", value: "enter email"}
            button '.js-add-button.button', 'Add'
        div '.js-autocomplete-results.autocomplete-results', ''
        div '.js-contacts-sync-button-container.contacts-sync-button-container', ''
renderForm = ck.compile(formTmpl)

contactsSyncButtomTmpl = ->
    if @hasContacts
        imgSrc = '/s/img/refresh-contacts-ico.png'
    else if @source is 'google'
        imgSrc = '/s/img/add-google-contacts-ico.png'
    else if @source is 'facebook'
        imgSrc = '/s/img/add-facebook-contacts-ico.png'

    if @hasContacts
        if @source is 'google'
            caption = 'Refresh my Google contacts'
        else if @source is 'facebook'
            caption = 'Refresh my Facebook contacts'
    else
        if @source is 'google'
            caption = 'Show my Google contacts'
        else if @source is 'facebook'
            caption = 'Show my Facebook contacts'
    button '.js-sync-contacts-button.contact-sync-button.button', {source: @sourceConstant}, ->
        img src: imgSrc
        span caption
renderContactsSyncButton = ck.compile(contactsSyncButtomTmpl)

contactsRefreshedMessageTmpl = ->
    div '.contacts-refreshed', ->
        img src: '/s/img/contacts-refreshed.png'
        if @source is 'google'
            text 'Google contacts refreshed '
        else if @source is 'facebook'
            text 'Facebook contacts refreshed '
renderRefreshedMessage = ck.compile(contactsRefreshedMessageTmpl)

userTmpl = ->
    div ".js-autocomplete-item.autocomplete-item", ->
        div '.avatar', {style: "background-image: url(#{h(@item.avatar)})"}, h(@item.initials)
        span {title: "#{h(@item.name)} #{h(@item.email)}"}, ->
            span '.name', h(@item.name)
            span '.email', h(@item.email)
renderUser = ck.compile(userTmpl)

cmpContacts = (a, b) ->
    compareContactsByNameAndEmail(a.data, b.data)

class Autocompleter
    constructor: (@_getContacts, @_$resultsContainer, @_renderItem, @_$queryInput, @_maxItemsToShow, @_selectHandler) ->
        @_getContacts(@_init)

    _init: (@_data) =>
        @_data.sort(cmpContacts)
        @_renderData()
        @_$queryInput.on 'keyup focus', @_filterParticipantsHandler
        @_$resultsContainer.on 'mouseover', '.js-autocomplete-item', (event) =>
            @_$resultsContainer.find('.js-autocomplete-item').removeClass('acSelect')
            $(event.currentTarget).addClass('acSelect')
        @_$resultsContainer.on 'click', '.js-autocomplete-item', (event) =>
            event.stopPropagation()
            item = $(event.currentTarget).data('item')
            @_selectHandler(item)

    _renderData: ->
        @_$resultsContainer.empty()
        result = ''
        i = 0
        for item in @_data
            break if i >= @_maxItemsToShow
            if not item.hide
                @_$resultsContainer.append($(@_renderItem({item: item.data})).data(item: item.data)[0])
                i += 1
        $(@_$resultsContainer.find('.js-autocomplete-item')[0]).addClass('acSelect')

    _filterParticipantsHandler: (event) =>
        switch event.keyCode
            when KeyCodes.KEY_END, KeyCodes.KEY_HOME, KeyCodes.KEY_SHIFT, KeyCodes.KEY_CTRL, KeyCodes.KEY_ALT, KeyCodes.KEY_LEFT, KeyCodes.KEY_RIGHT, KeyCodes.KEY_TAB then
            when KeyCodes.KEY_UP then @_focusPrev()
            when KeyCodes.KEY_DOWN then @_focusNext()
            when KeyCodes.KEY_ENTER
                $activeElem = @_$resultsContainer.find('.acSelect')
                if $activeElem.length == 1
                    @_selectHandler($activeElem.data('item'))
                    break
                @_selectHandler()
            else
                currentString = $(event.currentTarget).val().toLowerCase()
                @__filterParticipants(currentString)
                @_renderData()

    _focusNext: ->
        $selectedItem = @_$resultsContainer.find('.js-autocomplete-item.acSelect')
        $nextAfterSelectedItem = $selectedItem.next('.js-autocomplete-item')
        if $nextAfterSelectedItem.length > 0
            $selectedItem.removeClass('acSelect')
            $nextAfterSelectedItem.addClass('acSelect')

    _focusPrev: ->
        $selectedItem = @_$resultsContainer.find('.js-autocomplete-item.acSelect')
        $prevBeforeSelectedItem = $selectedItem.prev('.js-autocomplete-item')
        if $prevBeforeSelectedItem.length > 0
            $selectedItem.removeClass('acSelect')
            $prevBeforeSelectedItem.addClass('acSelect')

    __filterParticipants: (filterString) ->
        for item in @_data
            if item.searchString.search(filterString) == -1
                item.hide = true
            else
                item.hide = false

    getData: ->
        @_data

    getActiveItem: ->
        $activeElem = @_$resultsContainer.find('.acSelect')
        if $activeElem.length == 1
            return $activeElem.data('item')

    reset: ->
        @_getContacts((@_data) =>
            @_data.sort(cmpContacts)
            @_$queryInput.val('')
            @__filterParticipants('')
            @_renderData()
        )

    restart: ->
        @_getContacts((@_data) =>
            @_data.sort(cmpContacts)
            @_renderData()
        )

    destroy: ->
        delete @_data
        @_$resultsContainer.empty()


class AddParticipantForm
    constructor: (@_$container, @_maxItemsToShow, @_addButtons, @_waveProcessor, @_contactSelectHandler, @_contactButtonHandler) ->
        @_getContacts(@_renderForm)

    _getContacts: (callback, fromServer = false) =>
        @_waveProcessor.getUserContacts (err, users) =>
            return console.warn('Failed to load contacts', err) if err or not users
            userContacts = ({searchString: user.getSearchString(), data: user.getDataForAutocomplete()} for user in users)
            callback(userContacts)
        , fromServer

    _renderForm: (userContacts) =>
        res = renderForm({addButtons: @_addButtons})
        res = DomUtils.parseFromString(res)
        @_$container[0].appendChild(res)
        @_$syncContactsButtonContainer = @_$container.find('.js-contacts-sync-button-container')
        @_renderSyncBlock(userContacts)
        @_$syncContactsButtonContainer.on('click', '.js-sync-contacts-button', @_contactButtonHandler)
        @_$addButton = @_$container.find('.js-add-button')
        @_$queryInput = @_$container.find('.js-input-email')
        @_$queryInput.attr('textColor', @_$queryInput.css('color'))
        @_$queryInput.bind 'focus', =>
            @_$queryInput.val(if @_$queryInput.val() == 'enter email' then '' else @_$queryInput.val())
            @_$queryInput.css('color', '#000')
        @_$queryInput.bind 'blur', =>
            return if @_$queryInput.val() != ''
            @_$queryInput.val('enter email')
            @_$queryInput.css('color', @_$queryInput.attr('textColor'))
        $resultsContainer = @_$container.find('.js-autocomplete-results')
        @_autocompleter = new Autocompleter(@_getContacts, $resultsContainer, renderUser, @_$queryInput, @_maxItemsToShow, @_contactSelectHandler)
        @_initEvents()

    _initEvents: ->
        @_$addButton.on 'click', =>
            @_contactSelectHandler(@_autocompleter.getActiveItem())

    _renderSyncBlock: (userContacts, justRefreshedSource) ->
        contactSources = getContactSources(userContacts)
        @_$syncContactsButtonContainer.empty()
            .append(@_renderGoogleContactsSyncButton(contactSources, justRefreshedSource))
            .append(@_renderFacebookContactsSyncButton(contactSources, justRefreshedSource))

    _renderGoogleContactsSyncButton: (contactSources, justRefreshedSource) ->
        params =
            source: 'google'
            hasContacts: contactSources.google
            sourceConstant: contactsConstants.SOURCE_NAME_GOOGLE
        if justRefreshedSource is contactsConstants.SOURCE_NAME_GOOGLE
            return renderRefreshedMessage(params)
        else
            return renderContactsSyncButton(params)

    _renderFacebookContactsSyncButton: (contactSources, justRefreshedSource) ->
        params =
            source: 'facebook'
            hasContacts: contactSources.facebook
            sourceConstant: contactsConstants.SOURCE_NAME_FACEBOOK
        if justRefreshedSource is contactsConstants.SOURCE_NAME_FACEBOOK
            return renderRefreshedMessage(params)
        else
            return renderContactsSyncButton(params)

    show: ->
        @_autocompleter.reset()
        @_$container.show()
        @_renderSyncBlock(@_autocompleter.getData())
        # Ставим обработку события на следующий tick, чтобы не сработать на обработке этого клика
        window.setTimeout =>
            $(document).on 'keydown.closeAddParticipantBlock', (e) =>
                return if e.keyCode != 27
                @hide()
            $(document).on 'click.addParticipantBlock', (e) =>
                return if $(e.target).closest('.js-add-form, .js-add-select-selectBox-dropdown-menu').length != 0
                @hide()
        , 0

    hide: ->
        @_$container.hide()
        $(document).off 'keydown.closeAddParticipantBlock'
        $(document).off 'click.addParticipantBlock'

    isVisible: ->
        @_$container.is(':visible')

    refreshContacts: (justRefreshedSource) ->
        @_renderSyncBlock(@_autocompleter.getData(), justRefreshedSource)
        @_autocompleter.restart()

    restartAutocompleter: ->
        @_autocompleter.restart()

    destroy: ->
        @hide()
        @_autocompleter.destroy()
        delete @_autocompleter
        @_$container.empty()

module.exports = {AddParticipantForm, renderContactsSyncButton}