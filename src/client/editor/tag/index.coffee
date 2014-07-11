ck = window.CoffeeKup

renderTag = ck.compile ->
    span '.blip-tag-container', ->
        span '.js-blip-tag.blip-tag', ->
            span '.blip-tag-text', "##{h(@text)}"

renderTagInput = ck.compile ->
    span '.tag-input-container', ->
        input '.js-tag-input .tag-input', {type: "text", tabindex: "0"}
        span {style: "position: absolute; left: 3px;"}, '#'

{badCharacters} = require('../../tag/constants')
badCharactersRegExp = new RegExp("[#{badCharacters}]", 'g')

class Tag
    constructor: (@_text) ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        $(@_container).append(renderTag({text: @_text}))
        @_processor = require('../../tag/processor').instance
        @_processor.addTag(@_text)
        @_init()

    getContainer: -> @_container

    _init: ->
        return if !window.loggedIn
        $(@_container).find('.js-blip-tag').addClass('clickable')
        $(@_container)
        .on 'mousedown', (e) ->
            e.preventDefault()
        .on 'click', =>
            @_processor.getCurWave (curWave) =>
                sharedState = curWave.getModel().getSharedState()
                @_processor.findTopicListByTagText(@_text, sharedState)


class TagInput
    constructor: ->
        @_container = document.createElement 'span'
        @_container.contentEditable = 'false'
        $container = $(@_container)
        $container.append(renderTagInput())
        @_input = $container.find('.js-tag-input')[0]
        @_tagProcessor = require('../../tag/processor').instance
        @_activateInputField()

    _insertTag: (tag) ->
        return @_destroyInputField() if not tag
        $(@_container).trigger('tagInserted', tag)
        _gaq.push(['_trackEvent', 'Tag', 'Tag creation', @insertionEventLabel || 'Hotkey'])

    _filterInput: =>
        curVal = $(@_input).val()
        $(@_input).val(curVal.replace(badCharactersRegExp, ''))

    _activateInputField: ->
        $input = $(@_input)
        autocompleter =
            $input.val('').autocomplete({
                getData: @_tagProcessor.getTags
                onItemSelect: (item) => @_insertTag(item.value)
                matchInside: yes
                minChars: 0
                preventDefaultTab: yes
                autoWidth: null
                onFinish: @_destroyInputField
                delimiterKeyCode: -1
                delay: 0
            }).data('autocompleter')
        $input.keypress (e) =>
            return if e.keyCode != 13 and e.keyCode != 32
            @_insertTag($input.val())
            e.stopPropagation()
            e.preventDefault()
        $input.on 'input', @_filterInput
        $input.blur =>
            # Так делает jquery-autocomplete
            window.setTimeout =>
                @_destroyInputField()
            , 200
        autocompleter.activate()

    _destroyInputField: =>
        autocompleter = $(@_input).data('autocompleter')
        return if not autocompleter
        autocompleter.deactivate(false)
        $(@_container).trigger('blur')

    getContainer: ->
        @_container

    focus: ->
        @_input.focus()

    getValue: ->
        $(@_input).val()

    destroy: ->
        delete @_tagProcessor
        $(@_input).data('autocompleter')?.dom.$results.remove()
        $(@_container).remove()


module.exports = {Tag, TagInput}