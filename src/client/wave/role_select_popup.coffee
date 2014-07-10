{PopupContent} = require('../popup/')
ck = window.CoffeeKup

renderRoleSelect = ck.compile ->
    groupName = Math.random()
    for [roleId, roleName] in @roles
        div '.role', ->
            inputId = Math.random()
            params = {name: groupName, type: 'radio', id: inputId}
            if @curState is roleId
                params.checked = 'checked'
            input ".js-role-#{roleId}", params
            label {for: inputId}, roleName

class RoleSelectPopup extends PopupContent
    constructor: (roles, getState, stateChangeCallback) ->
        @_container = document.createElement('span')
        $c = $(@_container)
        $c.append(renderRoleSelect({curState: getState(), roles}))
        for [roleId] in roles
            do (roleId) ->
                roleNode = $c.find(".js-role-#{roleId}")[0]
                $(roleNode).on 'change click', ->
                    stateChangeCallback(roleId) if roleNode.checked

    getContainer: -> @_container

    getInternalContainerClass: -> 'role-selector-popup js-role-selector-popup'

    destroy: ->

module.exports = {RoleSelectPopup}