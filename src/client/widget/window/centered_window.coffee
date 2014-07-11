Window = require('./').Window
renderCenteredWindowBg = require('./template').renderCenteredWindowBg

class CenteredWindow extends Window
    __createDom: (params) ->
        super(params)
        tmpEl = document.createElement('span')
        $(tmpEl).append(renderCenteredWindowBg())
        @_container = tmpEl.firstChild
        @_container.appendChild(@_wnd)

    __addGlobalListeners: ->
        @_container.addEventListener('mousedown', @__handleOutsideEvent, no)

    __removeGlobalListeners: ->
        @_container.removeEventListener('mousedown', @__handleOutsideEvent, no)

    getContainer: ->
        @_container

    destroy: ->
        super()
        $(@_container).remove()
        delete @_container

    open: ->
        document.body.appendChild(@_container)
        super()
        $(@_container).show()

    close: (force = no) =>
        super(force)
        $(@_container).hide()

exports.CenteredWindow = CenteredWindow