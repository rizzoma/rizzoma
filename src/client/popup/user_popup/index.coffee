{PopupContent, popup} = require('../')
{renderUserComnonPopup, renderUserBottomPopup, renderUserTopPopup} = require('./template')

class UserPopup extends PopupContent
    constructor: (args...) ->
        @_init(args...)
        
    _init: (@_user) ->
        @_render()
    
    _render: ->
        @_container = document.createElement('span')
        @_commonBlockRender()
        @topBlockRender()
        @bottomBlockRender()
    
    _commonBlockRender: ->
        ###
        Рендерим блоки с инфой о юзере
        ###
        $(@_container).append(renderUserComnonPopup())
        
    topBlockRender: ->
        ###
        Рендерим верхний с инфой о юзере
        ###
        top_block = $(@_container).find('.js-user-popup-menu-top-block')[0]
        $(top_block).append(renderUserTopPopup(@_user.toObject()))
    
    bottomBlockRender: =>
    
    destroy: ->
        $(@_container).remove()
        @_container = null
    
    getContainer: ->
        @_render() if not @_container
        return @_container

setUserPopupBehaviour = (node, UserPopupClass, args...) ->
    timeout = null
    delay = 500
    $(node).bind 'click', (event) ->
        if timeout?
            clearTimeout(timeout)
            timeout = null
        popup.hide()
        popup.render(new UserPopupClass(args...), event.target)
        popup.show()
        return false
        
    $(node).bind 'mousedown', ->
        return false
    
#    $(node).hover( (event) ->
#        if timeout?
#            clearTimeout(timeout)
#            timeout = null
#        timeout = setTimeout(->
#            popup.hide()
#            popup.render(new UserPopupClass(args...), event.target)
#            popup.show()
#            timeout = null
#        , delay)
#    , ->
#        if timeout?
#            clearTimeout(timeout)
#            timeout = null
#    )
        
exports.setUserPopupBehaviour = setUserPopupBehaviour

exports.UserPopup = UserPopup