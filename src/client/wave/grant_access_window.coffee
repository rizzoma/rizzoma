ModalWindow = require('../widget/window/modal_window').ModalWindow
{ROLES, ROLE_OWNER} = require('./participants/constants')

tmpl = ->
    div 'grant-access-wnd', ->
        div ->
            span "Add "
            span 'user', "#{h(@user)}"
            span " as "
            select ->
                for role in @ROLES when role.id isnt @ROLE_OWNER
                    attr = {value: role.id}
                    attr.selected = yes if role.id is @role
                    option attr, role.name.toLowerCase()
            if @title
                span " to topic:"
        div 'title', "#{h(@title || '')}"
        div 'button-block', ->
            button 'js-add button', 'Add'
            button 'js-cancel button', 'Cancel'

render = window.CoffeeKup.compile(tmpl)

class GrantAccessWindow extends ModalWindow
    constructor: ->
        params =
            title: 'Grand access'
            closeButton: yes
            closeOnOutsideAction: yes
        super(params)

    open: (title, user, role, add) ->
        params = {user, title, role, ROLES, ROLE_OWNER}
        @setContent(render(params))
        $body = $(@getBodyEl())
        $body.find('.js-cancel').on 'click', =>
            @destroy()
        $body.find('.js-add').on 'click', =>
            add($body.find('select').val(), ->)
            @destroy()
        super()

module.exports = GrantAccessWindow
