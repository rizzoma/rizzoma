Conf = require('../conf').Conf
CouchImportProcessor = require('../import/couch_processor').CouchImportProcessor

app = require('./web_base').app

LINK_REDIRECT_PREFIX = '/r/gw/'
externalRedirectTemplate = Conf.getTemplate().compileFile('import/external_redirect.html')

# Redirect from old Google Wave links to imported waves (Редирект из google wave на наши топики)
app.get "#{LINK_REDIRECT_PREFIX}:domain/:waveId/:waveletId?/:blipId?", (req, res) =>
    domain = req.params.domain
    gWaveId = req.params.waveId
    waveletId = req.params.waveletId || "conv+root"
    blipId = req.params.blipId
    sourceId = domain + '!' + gWaveId + '_' + domain + '!' + waveletId
    CouchImportProcessor.getById(sourceId, (err, source) ->
        if err or not source.importedWaveId
            link = 'https://wave.google.com/wave/waveref/' + domain + '/' + gWaveId + '/~/' + waveletId
            link += '/' + blipId if blipId
            params =
                url: link
            try
                res.send externalRedirectTemplate.render(params)
            catch e
                Conf.getLogger('http').error(e)
                res.send 500
        else
            link = "/topic/#{source.importedWaveUrl}/"
            if blipId and source.blipIds and source.blipIds[blipId]
                link += "#{source.blipIds[blipId]}/"
            res.redirect(link)
    )