var mediaConstraints = {
    video: true,
    audio: true
};
//var mediaConstraints = {"audio": true, "video": {"mandatory": {}, "optional": []}};

function requestUserMedia(callback) {
    // Call into getUserMedia via the polyfill (adapter.js).
    try {
        console.log('Requesting access to local media with mediaConstraints:\n' +
                          '  \'' + JSON.stringify(mediaConstraints) + '\'');
        getUserMedia(mediaConstraints, function(stream) {
            callback(null, stream);
        }, function(err) {
            callback(err);
        });
    } catch (e) {
        callback(e);
    }
}