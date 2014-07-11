###
Роль для приложения импорта.
Постановка волн в очередь для импорта и отслеживание статуса импортирования
###

app = require('./web_base').app

IMPORT_URL = '/import/'

ImportView = require('../import/views').ImportView

app.get(IMPORT_URL, ImportView.statistic)

app.post(IMPORT_URL, ImportView.saveSource)

app.get(IMPORT_URL + 'ping/', ImportView.ping)

app.get(IMPORT_URL + 'analytics/', ImportView.countOfImported)

LINK_REDIRECT_PREFIX = require('../import/source_parser').LINK_REDIRECT_PREFIX
app.get("#{LINK_REDIRECT_PREFIX}:domain/:waveId/:waveletId?/:blipId?", ImportView.waveLinkRedirect)

# /import redirect: append slash
app.get '/import', (req, res) ->
    res.redirect(IMPORT_URL)
