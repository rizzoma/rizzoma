{Request} = require('../../share/communication')
MicroEvent = require('../../utils/microevent')

class TagProcessor
    constructor: (@_rootRouter) ->
        @_tags = []

    _updateNavigationTagList: ->
        request = new Request(tags: @_tags)
        try @_rootRouter.handle('navigation.updateTagList', request)

    _addTag: (tag) ->
        lowerTag = tag.toLowerCase()
        for t in @_tags
            return no if lowerTag is t.toLowerCase()
        @_tags.push(tag)
        yes

    _addTags: (tags) ->
        tagWasAdded = no
        for tag in tags
            tagWasAdded = @_addTag(tag) || tagWasAdded
        @_updateNavigationTagList() if tagWasAdded

    requestTags: ->
        request = new Request {}, (err, tags) =>
            return console.warn("Could not get tag list", err) if err
            @_addTags(tags)
        @_rootRouter.handle('network.gtag.getGTagList', request)

    getTags: => @_tags

    addTag: (tag) ->
        @_updateNavigationTagList() if @_addTag(tag)

    getCurWave: (callback) ->
        request = new Request({}, callback)
        @_rootRouter.handle('wave.getCurWave', request)

    findTopicListByTagText: (text, sharedState) ->
        request = new Request({text, sharedState}, ->)
        @_rootRouter.handle('navigation.findTopicListByTagText', request)

module.exports = {TagProcessor}
MicroEvent.mixin(TagProcessor)
