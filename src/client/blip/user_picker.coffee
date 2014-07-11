{renderContact} = require('../user/template')
{isEmail} = require('../utils/string')
MicroEvent = require('../utils/microevent')
compareContacts = require('../user/utils').compareContactsByParticipanceNameAndEmail

class UserPicker
    ###
    Класс для выбора участника. Дополняет input autocomplete'ом, показывая участников из блипа и из списка
    контактов пользователя.
    ###
    constructor: (@_waveViewModel) ->
        @_contacts = []
        @_data = null
        @_getContactList()

    _getContactList: ->
        require('../wave/processor').instance.getUserContacts (err, users) =>
            return console.warn("User picker could not get user contacts:", err) if err
            @_contacts = users

    activate: (@_input, autocompleteContainer) ->
        $input = $(@_input)
        autocompleter =
            $input.autocomplete({
                getData: @_getData
                onItemSelect: (item) => @emit('select-contact', item.data[0])
                onFinish: => @emit('finish')
                sortFunction: (a, b) -> compareContacts(a.data[0], b.data[0])
                selectFirst: yes
                matchInside: yes
                minChars: 0
                preventDefaultTab: yes
                showResult: renderContact
                autoWidth: null
                delimiterKeyCode: -1
                delay: 0
                resultsContainer: autocompleteContainer
                autoPosition: !autocompleteContainer
                autoFocus: false
            }).data('autocompleter')
        $input.keypress (e) =>
            return if e.keyCode != 13
            e.stopPropagation()
            e.preventDefault()
            @emit('select-email', $input.val())
        $input.blur =>
            # jquery-autocomplete делает так же, нет смысла выдумывать что-то более серьезное
            window.setTimeout =>
                @emit('finish')
            , 200
        $input.focus ->
            autocompleter.activate()

    _getData: =>
        return @_data if @_data?
        participants = @_waveViewModel.getParticipants()
        emailsAreEqual = (first, second) ->
            return if typeof(first) isnt 'string' or typeof(second) isnt 'string'
            first.toLowerCase() is second.toLowerCase()
        uniqueContacts = []
        for contact in @_contacts
            isUnique = true
            for participant in participants
                if emailsAreEqual(contact.getEmail(), participant.getEmail())
                    isUnique = false
                    break
            uniqueContacts.push(contact) if isUnique
        p.isParticipant = true for p in participants
        @_data = []
        for user in participants when not user.isAnonymous()
            @_data.push([user.getSearchString(), user.getDataForAutocomplete(true)])
        for user in uniqueContacts when not user.isAnonymous()
            @_data.push([user.getSearchString(), user.getDataForAutocomplete(false)])
        return @_data

    isValid: (email) -> isEmail(email)

    getAutocompleteContainer: ->
        $(@_input).data('autocompleter')?.dom?.$results[0]

    destroy: ->
        @removeListeners('select-email')
        @removeListeners('select-contact')
        @removeListeners('finish')
        autocompleter = $(@_input).data('autocompleter')
        return if not autocompleter
        autocompleter.deactivate(false)
        autocompleter.dom.$results.remove()


MicroEvent.mixin(UserPicker)
module.exports = {UserPicker}