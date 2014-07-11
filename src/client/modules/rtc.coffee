Request = require('../../share/communication').Request
DomUtils = require('../utils/dom')

pcConfig = {
    iceServers: [
        url: 'turn:hackathon@s3-lon.mnsbone.net',
#        url: 'turn:s3-lon.mnsbone.net'
        credential: 'Turn4Hack'
#        username: 'hackathon'
    ]
}

sdpConstraints =
    mandatory:
        OfferToReceiveAudio: yes
        OfferToReceiveVideo: yes

pcConstraints = {"optional": [{"DtlsSrtpKeyAgreement": true}]};

offerConstraints = {"optional": [], "mandatory": {}};

tmpl = ->
    div {id: 'videoContainer', ondblclick: 'enterFullScreen()'}, ->
        style '''
                  #videoContainer {
                      background-color: #000000;
                      position: absolute;
                      bottom: 200px;
                      margin: 0px auto;
                      -webkit-perspective: 1000;
                      width: 100%;
                      min-height: 200px;
                      z-index: 200;
                    }
                  .tips-hidden #videoContainer {
                      bottom: 81px;
                  }
                    #card {
                      -webkit-transition-property: rotation;
                      -webkit-transition-duration: 2s;
                      -webkit-transform-style: preserve-3d;
                    }
                    #local {
                      position: absolute;
                      width: 100%;
                      -webkit-transform: scale(-1, 1);
                      -webkit-backface-visibility: hidden;
                    }
                    #remote {
                      position: absolute;
                      width: 100%;
                    }
                    #mini {
                      position: absolute;
                      height: 30%;
                      width: 30%;
                      bottom: 32px;
                      right: 4px;
                      -webkit-transform: scale(-1, 1);
                      opacity: 1.0;
                    }
                    #localVideo {
                      width: 100%;
                      height: 100%;
                      opacity: 0;
                      -webkit-transition-property: opacity;
                      -webkit-transition-duration: 2s;
                    }
                    #remoteVideo {
                      width: 100%;
                      height: 100%;
                      opacity: 0;
                      -webkit-transition-property: opacity;
                      -webkit-transition-duration: 2s;
                    }
                    #miniVideo {
                      width: 100%;
                      height: 100%;
                      opacity: 0;
                      -webkit-transition-property: opacity;
                      -webkit-transition-duration: 2s;
                    }
                    #hangup {
                     font-size: 13px; font-weight: bold;
                     color: #FFFFFF;
                     width: 128px;
                     height: 24px;
                     background-color: #808080;
                     border-style: solid;
                     border-color: #FFFFFF;
                     margin: 2px;
                    }
                  '''
        div id:"card", ->
            div id:"local", ->
                video {id: "localVideo", autoplay: "autoplay", muted: "true"}, ->
        div id:"remote", ->
            video {id: "remoteVideo", autoplay: "autoplay"}, ->
            div id: "mini", ->
                video {id: "miniVideo", autoplay: "autoplay", muted: "true"}, ->

renderTmpl = window.CoffeeKup.compile(tmpl)

mergeConstraints = (cons1, cons2) ->
    merged = cons1;
    for name of cons2.mandatory
      merged.mandatory[name] = cons2.mandatory[name];
    merged.optional.concat(cons2.optional);
    return merged;

extractSdp = (sdpLine, pattern) ->
    result = sdpLine.match(pattern)
    if (result && result.length == 2) then result[1] else null

setDefaultCodec = (mLine, payload) ->
    elements = mLine.split(' ')
    newLine = new Array();
    index = 0;
    for element in elements
        if (index is 3) # Format of media starts from the fourth.
            newLine[index++] = payload; # Put target payload to the first.
        if (element isnt payload)
          newLine[index++] = element;
    newLine.join(' ')

removeCN = (sdpLines, mLineIndex) ->
    mLineElements = sdpLines[mLineIndex].split(' ')
    # Scan from end for the convenience of removing an item.
    for i in [sdpLines.length- 1..0]
        payload = extractSdp(sdpLines[i], /a=rtpmap:(\d+) CN\/\d+/i)
        if (payload)
            cnPos = mLineElements.indexOf(payload)
            if (cnPos isnt -1)
                # Remove CN payload from m line.
                mLineElements.splice(cnPos, 1)
            # Remove CN line in sdp
            sdpLines.splice(i, 1)
    sdpLines[mLineIndex] = mLineElements.join(' ')
    sdpLines

preferOpus = (sdp) ->
    sdpLines = sdp.split('\r\n');

    # Search for m line.
    for sdpLine, i in sdpLines
        if (sdpLine.search('m=audio') isnt -1)
            mLineIndex = i;
            break;
    if (mLineIndex is null)
        return sdp;

    # If Opus is available, set it as the default in m line.
    for sdpLine in sdpLines
        if (sdpLine.search('opus/48000') isnt -1)
            opusPayload = extractSdp(sdpLine, /:(\d+) opus\/48000/i);
            if (opusPayload)
                sdpLines[mLineIndex] = setDefaultCodec(sdpLines[mLineIndex], opusPayload);
            break

    # Remove CN in m line and sdp.
    sdpLines = removeCN(sdpLines, mLineIndex);
    sdp = sdpLines.join('\r\n');
    sdp

class WebRtc
    constructor: (@_rootRouter) ->
        @_localStream = null
        @_remoteStream = null
        @_pc = null
        @_container = null
        @_initiator = null
        setTimeout =>
            @_subscribeToMessages()
        , 100

    _resize: =>
        console.log 'resize'
        if (@_remoteVideo.style.opacity is '1')
            aspectRatio = @_remoteVideo.videoWidth/@_remoteVideo.videoHeight;
        else if (@_localVideo.style.opacity is '1')
            aspectRatio = @_localVideo.videoWidth/@_localVideo.videoHeight;
        else
            console.error('return')
            return

        navPanel = document.getElementById('navigation-panel')
        innerHeight = navPanel.offsetHeight;
        innerWidth = navPanel.offsetWidth;
        videoWidth = if innerWidth < aspectRatio * innerHeight then innerWidth else aspectRatio * innerHeight;
        videoHeight = if innerHeight < innerWidth / aspectRatio then innerHeight else innerWidth / aspectRatio;
        containerDiv = @_container
        containerDiv.style.width = videoWidth + 'px';
        containerDiv.style.height = videoHeight + 'px';
#        containerDiv.style.left = (innerWidth - videoWidth) / 2 + 'px';
#        containerDiv.style.top = (innerHeight - videoHeight) / 2 + 'px';

    _showVideo: ->
        if @_container
            document.getElementById('navigation-panel').appendChild(@_container)
            $(window).on('resize', @_resize)
        span = document.createElement('span')
        span.appendChild(DomUtils.parseFromString(renderTmpl()))
        @_container = span.firstChild
        document.getElementById('navigation-panel').appendChild(@_container)
#        document.body.appendChild(@_container)
        @_localVideo = document.getElementById('localVideo')
        @_localVideo.addEventListener 'loadedmetadata', =>
            @_resize()
        @_miniVideo = document.getElementById('miniVideo')
        @_remoteVideo = document.getElementById('remoteVideo')
        @_card = document.getElementById('card')

    _hideVideo: ->
        @_container.parentNode.removeChild(@_container)

    _attachLocalStream: (@_localStream) ->
        @_showVideo()
        attachMediaStream(@_localVideo, @_localStream);
        @_localVideo.style.opacity = 1;

    _sendMessage: (msg) ->
        msg.waveId = @_waveId
        msg.userId = @_userId
        params =
            waveId: @_waveId
            toUserId: @_initiator || @_userId
            message: JSON.stringify(msg)
        callback = (err) ->
            return console.error(err) if err
#        console.log 'sending message', params
        console.log 'sending message to', params.toUserId
        request = new Request(params, callback)
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.messaging.sendToUser', request)

    _startCallingFlow: (waveId, userId) ->
        @_waveId = waveId
        @_userId = userId
        requestUserMedia (err, stream) =>
            if err
                alert(err)
                return
            @_attachLocalStream(stream)
            @_sendMessage({type: 'takeCall', fromUserId: window.userInfo.id})

    _waitForRemoteVideo: =>
        #Call the getVideoTracks method via adapter.js.
        videoTracks = @_remoteStream.getVideoTracks()
        if (videoTracks.length is 0 || @_remoteVideo.currentTime > 0)
            @_transitionToActive();
        else
            setTimeout(@_waitForRemoteVideo, 100)

    _transitionToActive: ->
        console.warn 'transition to active'
        console.log @_remoteVideo
        @_remoteVideo.style.opacity = 1;
        @_card.style.webkitTransform = 'rotateY(180deg)';
        setTimeout =>
            @_localVideo.src = ''
        , 500
        setTimeout =>
            @_miniVideo.style.opacity = 1;
        , 1000
        # Reset window display according to the asperio of remote video.
        @_resize()
#        setStatus('<input type=\'button\' id=\'hangup\' value=\'Hang up\' \
#                onclick=\'onHangup()\' />');

    _onRemoteStreamAdded: (event) =>
        console.warn('Remote stream added.');
        reattachMediaStream(@_miniVideo, @_localVideo)
        attachMediaStream(@_remoteVideo, event.stream)
        @_remoteStream = event.stream;
        @_waitForRemoteVideo()

    _onRemoteStreamRemoved: ->
        console.log('Remote stream removed.');

    _onIceCandidate: (event) =>
        console.log 'onIceCandidate', event
        if event.candidate
            @_sendMessage(
                type: 'candidate',
                label: event.candidate.sdpMLineIndex,
                id: event.candidate.sdpMid,
                candidate: event.candidate.candidate
            )
        else
            console.log('End of candidates.');

    _createPeerConnection: ->
        try
            # Create an RTCPeerConnection via the polyfill (adapter.js).
            pc = new RTCPeerConnection(pcConfig, pcConstraints);
            pc.onicecandidate = @_onIceCandidate
            console.log('Created RTCPeerConnnection with:\n' +
                      '  config: \'' + JSON.stringify(pcConfig) + '\';\n' +
                      '  constraints: \'' + JSON.stringify(pcConstraints) + '\'.');
        catch e
            console.log('Failed to create PeerConnection, exception: ' + e.message);
            alert('Cannot create RTCPeerConnection object; WebRTC is not supported by this browser.');
            return;

        pc.onaddstream = @_onRemoteStreamAdded
        pc.onremovestream = @_onRemoteStreamRemoved
        @_pc = pc

    _setLocalAndSendMessage: (sessionDescription) =>
#        Set Opus as the preferred codec in SDP if Opus is present.
#        sessionDescription.sdp = preferOpus(sessionDescription.sdp) # TODO: preferOpus
        @_pc.setLocalDescription(sessionDescription);
        @_sendMessage(sessionDescription);

    _respondToCall: ->
        constraints = mergeConstraints(offerConstraints, sdpConstraints); # TODO: merge constraints
#        constraints = sdpConstraints
        console.log('Sending offer to peer, with constraints: \n' +
                    '  \'' + JSON.stringify(constraints) + '\'.')
        @_pc.createOffer(@_setLocalAndSendMessage, null, constraints);

    _takeCall: (msg) ->
        console.warn "taking a call from #{msg.waveId} and #{msg.userId}"
        requestUserMedia (err, stream) =>
            if err
                alert(err)
                return
            @_attachLocalStream(stream)
            @_createPeerConnection();
            console.log('Adding local stream.')
            @_pc.addStream(@_localStream)
            @_initiator = msg.fromUserId
            @_respondToCall()

    _takeOffer: (msg) ->
        console.warn "taking an offer from #{msg.waveId} and #{msg.userId}"
        @_createPeerConnection()
#        if (stereo)
#            msg.sdp = addStereo(message.sdp); # TODO: addStereo
        @_pc.setRemoteDescription(new RTCSessionDescription(msg));
        console.log('Sending answer to peer, with constraints: \n' +
                '  \'' + JSON.stringify(sdpConstraints) + '\'.')
        @_pc.createAnswer(@_setLocalAndSendMessage, null, sdpConstraints);

    _takeAnswer: (msg) ->
        console.log "taking an answer from #{msg.waveId} and #{msg.userId}", msg
#        if (stereo)
#            message.sdp = addStereo(message.sdp); # TODO: addStereo
        @_pc.setRemoteDescription(new RTCSessionDescription(msg));

    _takeCandidate: (msg) ->
        console.log "taking a candidate from #{msg.waveId} and #{msg.userId}"
        candidate = new RTCIceCandidate({sdpMLineIndex: msg.label, candidate: msg.candidate});
        @_pc.addIceCandidate(candidate);

    _handleMessage: (msg) ->
        try
            msg = JSON.parse(msg.message)
            @_waveId = msg.waveId
            @_userId = msg.userId
        catch e
            return console.error('Could not parse message', msg)
        return unless msg
        switch msg.type
            when 'takeCall'
                @_takeCall(msg)
            when 'offer'
                @_takeOffer(msg)
            when 'answer'
                @_takeAnswer(msg)
            when 'candidate'
                @_takeCandidate(msg)
            else
                console.error('Unknown message received', msg)

    _subscribeToMessages: ->
        processMsg = (err, msg) =>
            return err if err
            @_handleMessage(msg)
        request = new Request({resource: @_resource = Math.random()}, processMsg)
        request.setProperty('recallOnDisconnect', true)
        request.setProperty('wait', true)
        @_rootRouter.handle('network.messaging.subscribeUser', request)

    callUser: (waveId, userId) -> @_startCallingFlow(waveId, userId)

module.exports =
    WebRtc: WebRtc
    instance: null