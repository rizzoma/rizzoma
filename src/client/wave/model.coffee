
# публичность волны
WAVE_SHARED_STATE_PUBLIC = 1
WAVE_SHARED_STATE_LINK_PUBLIC = 2
WAVE_SHARED_STATE_PRIVATE = 3
{ROLE_NO_ROLE} = require('./participants/constants')
EmitModel = require('../utils/emit_model')

class WaveModel extends EmitModel
    @EDITABLE_CHANGE: 'editableChange'
    @ACTIVE_BLIP_CHANGE: 'activeBlipChange'

    @PROPS: [
        '_editable'
        '_activeBlip'
    ]

    constructor: (@_doc, socialSharingUrl) ->
        super()
        @_init(@_doc, socialSharingUrl)

    _init: (@_doc, socialSharingUrl) ->
        @__props = ['_editable', '_activeBlip']
        @_rootBlipId = @_doc.snapshot.rootBlipId
        @_containerBlipId = @_doc.snapshot.containerBlipId
        @socialSharingUrl = socialSharingUrl
        @id = @_doc.name
        @serverId = @_doc.serverId
        @_editable = no

    getVersion: ->
        @_doc.version

    getServerId: ->
        @serverId

    getSharedState: ->
        ###
        Возвращает true, если в волна доступна всем пользователям
        @return: boolean
        ###
        return @_doc.snapshot.sharedState

    getRootBlipId: -> @_rootBlipId

    getContainerBlipId: ->
        @_containerBlipId

    getRole: (participantId, noRoleIfNotAdded=true) ->
        for p in @_doc.snapshot.participants
            return p.role if p.id is participantId
        if noRoleIfNotAdded
            return ROLE_NO_ROLE
        else
            return null

    getDefaultRole: ->
        @_doc.snapshot.defaultRole

    setActiveBlip: (blip) ->
        @__setProperty(@constructor.ACTIVE_BLIP_CHANGE, '_activeBlip', blip)

    getActiveBlip: -> @_activeBlip

    setEditable: (editable) ->
        @__setProperty(@constructor.EDITABLE_CHANGE, '_editable', editable)

    getEditable: -> @_editable

    getGDriveId: -> @_doc.snapshot.gDriveId

    getGDriveShareUrl: ->
        if gDriveId = @_doc.snapshot.gDriveId
            "https://drive.google.com/file/d/#{gDriveId}/edit?userstoinvite=%20"
        else
            null

    destroy: ->
        super()
        delete @_doc
        delete @_activeBlip

module.exports = {WaveModel, WAVE_SHARED_STATE_PUBLIC, WAVE_SHARED_STATE_LINK_PUBLIC, WAVE_SHARED_STATE_PRIVATE}
