CenteredWindow = require('../widget/window/centered_window').CenteredWindow
DomUtils = require('../utils/dom')

tmpl = ->
    div 'title', 'To embed Rizzoma topic use this HTML code'
    div ->
        textarea 'js-output', ''
    div ->
        div 'input-block', ->
            label {for: 'embeddedGeneratorWidth'}, 'Width: '
            input 'js-width text-input width-input', {
                id: 'embeddedGeneratorWidth'
                type: 'number'
                value: @minValue
                min: @minValue
            }
        div 'input-block', ->
            label {for: 'embeddedGeneratorHeight'}, 'Height: '
            input 'js-height text-input height-input', {
                id: 'embeddedGeneratorHeight'
                type: 'number'
                value: @minValue
                min: @minValue
            }
renderTmpl = window.CoffeeKup.compile(tmpl)

MIN_VALUE = 550

getValidValueFromInput = (input) ->
    val = parseInt(input.value) || MIN_VALUE
    val = MIN_VALUE if val < MIN_VALUE
    val

validateInputValue = ->
    val = getValidValueFromInput(@)
    @value = val if @value isnt (val + '')

class EmbeddedCodeGenerator extends CenteredWindow
    constructor: ->
        params =
            closeButton: yes
            closeOnOutsideAction: yes
            closeOnEsc: yes
        super(params)

    __createDom: (params) ->
        super(params)
        body = @getBodyEl()
        params = {minValue: MIN_VALUE}
        body.appendChild(DomUtils.parseFromString(renderTmpl(params)))
        DomUtils.addClass(body, 'embedded-code-generator')
        @_widthInput = body.getElementsByClassName('js-width')[0]
        @_heightInput = body.getElementsByClassName('js-height')[0]
        @_output = body.getElementsByClassName('js-output')[0]
        @_widthInput.addEventListener('change', validateInputValue, no)
        @_heightInput.addEventListener('change', validateInputValue, no)
        @_widthInput.addEventListener('input', @_updateOutput, no)
        @_heightInput.addEventListener('input', @_updateOutput, no)
        @_output.addEventListener('click', ->
            @select()
        , no)

    _updateOutput: =>
        width = getValidValueFromInput(@_widthInput)
        height = getValidValueFromInput(@_heightInput)
        @_output.value = "<iframe width=\"#{width}\" height=\"#{height}\" src=\"#{@_url}\" frameborder=\"0\" allowfullscreen></iframe>"

    open: (@_url) ->
        return console.warn('URL was not provided') unless @_url
        super()
        @_updateOutput()
        @_output.select()

instance = null
module.exports.get = -> instance ?= new EmbeddedCodeGenerator()
