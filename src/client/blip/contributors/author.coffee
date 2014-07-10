{renderAuthor} = require('./template')

class Author
    constructor: (args...) ->
        @_init(args...)

    _init: (@_waveViewModel, @_ids) ->
        @_createDom()

    _createDom: ->
        @_container = document.createElement 'span'
        @_render()

    _render: ->
        $(@_container).empty().unbind()
        user = @_waveViewModel.getUser(@_ids[0])
        params = {users: [user.toObject()]}
        params.users.push(@_waveViewModel.getUser(@_ids[1]).toObject()) if @_ids[1]
        $(@_container).append(renderAuthor(params))
        @_avatarContainer = $(@_container).find('.js-shown-contributor-avatar')

    updateAuthorInfo: (userIds) =>
        return if $.inArray(@_ids[0], userIds) is -1 and $.inArray(@_ids[1], userIds) is -1
        @_render()

    setIndicator: (userId) ->
        @_ids[1] = userId
        @_render()

    getContainer: ->
        @_container
    
    getAvatarContainer: ->
        @_avatarContainer

exports.Author = Author
