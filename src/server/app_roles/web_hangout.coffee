###
Роль, для обслуживания запросов, относящихся к hangout-приложению
###

Conf = require('../conf').Conf
app = require('./web_base').app

hangoutAppTemplate = Conf.getTemplate().compileFile('hangout/index.xml')
app.get('/hangout.xml', (req, res) ->
    ###
    Раздает xml с приложением.
    ###
    host = req.headers?.host
    hangoutAppConf = Conf.getHangoutConf()
    params =
        title: hangoutAppConf.title
        baseUrl: "http://#{host}#{Conf.getWaveUrl()}"
        devMode: hangoutAppConf.devMode
    res.send hangoutAppTemplate.render(params)
)