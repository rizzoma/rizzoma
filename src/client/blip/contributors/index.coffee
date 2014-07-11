renderContributorsContainer = require('./template').renderContributorsContainer
renderContributor = require('./template').renderContributor
{ParticipantPopup, canEditParticipant, canRemoveParticipant} = require('../../wave/participants')
{setUserPopupBehaviour, UserPopup} = require('../../popup/user_popup')
{ROLE_NO_ROLE} = require('../../wave/participants/constants')

class Contributors
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, contributors, @_author) ->
        @_contributors = []
        for contributor in contributors
            @_contributors.push contributor.id
        @_waveProcessor = require('../../wave/processor').instance
        @_createDom()
        @_initContributors()
        @_waveViewModel.on('participant-update', @_processParticiapntsChange)
        @_waveViewModel.on('usersInfoUpdate', @_updateContributorsInfo)
        @_bindAuthorPopup()

    _processParticiapntsChange: =>
        @_updateContributorsInfo(@_contributors)

    _createDom: ->
        @_container = document.createElement('span')
        $container = $(@_container)
        $container.append(renderContributorsContainer())
        @_contributorsContainer = $container.find('.js-contributors-container')[0]

    _initContributors: ->
        $container = $(@_contributorsContainer)
        users = @_waveViewModel.getUsers(@_contributors)
        for index, contributorId of @_contributors
            for user in users
                continue if user.getId() isnt contributorId
                @_insertContributor(index, user)
                break

    _insertContributor: (index, user) ->
        if @_contributorsContainer.childNodes.length <= index
            $container = $(@_contributorsContainer)
            $container.append(renderContributor(user.toObject()))
            $insertedNode = $container.children().last()
        else
            $node = $(@_contributorsContainer.childNodes[index])
            $node.before(renderContributor(user.toObject()))
            $insertedNode = $node.prev()
        @_setContributorParams($insertedNode, user)
        if @_contributorsContainer.childNodes.length == 2
            @_bindContributorsContainer(user.getId())

    _bindAuthorPopup: ->
        return if @_contributors.length > 1
        @_setContributorParams($(@_author.getAvatarContainer()), @_waveViewModel.getUser(@_contributors[0]))

    _bindContributorsContainer: (addUserId = null) ->
        @_author.setIndicator(addUserId) if addUserId
        $(@_author.getAvatarContainer()).bind 'click', =>
            $('.js-contributors-container:visible').hide()
            $(@_contributorsContainer).show()
            $(window).bind 'click', @_hideBlipContributors
            return false
        $(@_author.getAvatarContainer()).bind 'mousedown', =>
            return false

    _hideBlipContributors: (event) =>
        if $(@_contributorsContainer).is(':visible') and not $.contains(@_contributorsContainer, event.target) and @_contributorsContainer != event.target
            $(@_contributorsContainer).hide()
            $(window).unbind 'click', @_hideBlipContributors
        return false

    _updateContributorsInfo: (userIds) =>
        @_author.updateAuthorInfo(userIds)
        for id in userIds
            for node in @_contributorsContainer.childNodes
                $node = $(node)
                continue if $node.data('contributorId') isnt id
                user = @_waveViewModel.getUser(id)
                $node.after(renderContributor(user.toObject()))
                $insertedNode = $node.next()
                @_setContributorParams($insertedNode, user)
                $node.remove()
                break
        if @_contributorsContainer.childNodes.length > 1
            @_bindContributorsContainer()
        else
            @_bindAuthorPopup()

    _canEditParticipant: (userId) => canEditParticipant(@_waveViewModel, userId)

    _canRemoveParticipant: (userId) => canRemoveParticipant(@_waveViewModel, userId)

    _setContributorParams: ($node, user) ->
        userId = user.getId()
        $node.data('contributorId', userId)
        role = @_waveViewModel.getModel().getRole(userId)
        if role is ROLE_NO_ROLE
            setUserPopupBehaviour($node, UserPopup, user)
        else
            canEdit = => @_canEditParticipant(userId)
            canRemove = => @_canRemoveParticipant(userId)
            getRole = => @_waveViewModel.getModel().getRole(userId)
            setUserPopupBehaviour($node, ParticipantPopup, user, canEdit, canRemove, getRole, @_changeParticipantRole, @_removeParticipant)

    _removeParticipant: (userId) =>
        @_waveProcessor.removeParticipant(@_waveViewModel.getServerId(), userId, @_processResponse)

    _changeParticipantRole: (userId, roleId) =>
        @_waveProcessor.changeParticipantRole(@_waveViewModel.getServerId(), userId, roleId, @_processResponse)

    _processResponse: (err) =>
        @_waveProcessor.showPageError(err) if err

    _add: (contributor, index) ->
        @_contributors.splice index, 0, contributor.id
        user = @_waveViewModel.getUser(contributor.id)
        @_insertContributor(index, user)
        
    _remove: (contributor, index) ->
        @_contributors.splice index, 1
        $(@_contributorsContainer.childNodes[index]).remove()

    getContainer: ->
        @_container

    applyOp: (op) ->
        if op.ld
            @_remove op.ld, op.p.shift()
        if op.li
            @_add op.li, op.p.shift()

    destroy: ->
        delete @_author
        @_waveViewModel.removeListener('participant-update', @_processParticiapntsChange)
        @_waveViewModel.removeListener('usersInfoUpdate', @_updateContributorsInfo)
        delete @_waveViewModel

exports.Contributors = Contributors