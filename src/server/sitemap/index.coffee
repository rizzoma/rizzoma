fs = require('fs')
async = require('async')
path = require('path')
Conf = require('../conf').Conf
SearchController = require('../search/controller').SearchController
SHARED_STATE_PUBLIC = require('../wave/constants').SHARED_STATE_PUBLIC

class SitemapBlipSearchController extends SearchController

    searchPublicBlips: (callback) ->
        query = @_getQuery()
            .select(['wave_id', 'MAX(changed) AS groupchanged', 'MAX(content_timestamp) AS groupdate', 'wave_url'])
            .addQueryString('')
            .addAndFilter("shared_state = #{SHARED_STATE_PUBLIC}")
            .groupBy('wave_id')
            .orderBy('groupdate')
            .limit(5000)
        @executeQueryWithoutPostprocessing(query, callback)


HTML_SIZE_MIN_LIMIT = 500 # 500 байт

class Sitemap
    constructor: () ->
        @_dstPath = Conf.getSitemapConf().destinationPath
        @_logger = Conf.getLogger('sitemap')
        # settings for sitemap.xml
        @_sitemapIndexName = 'sitemap.xml'
        @_sitemapsBaseUrl = Conf.get('baseUrl')
        # pages_sitemap.xml:
        @_pagesSitemapName = 'pages_sitemap.xml'
        @_pagesBaseUrl = @_sitemapsBaseUrl
        @_pagesPath = path.join(__dirname, '../../../','lib/pages/')
        # public_topics_sitemap.xml:
        @_publicTopicsSitemapName = 'public_topics_sitemap.xml'
        @_publicTopicsBaseUrl = Conf.get('baseUrl') + '/topic'
        @_sitemapBlipSearchController = new SitemapBlipSearchController()

    _generateUrlsetXmlHeader: () ->
        return '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'

    _generateUrlsetXmlFooter: () ->
        return '</urlset>'

    _generateUrlXml: (url, lastmod, priority=0.5, freq='monthly') ->
        xml = '<url>\n'
        xml += '<loc>' + url + '</loc>\n'
        xml += '<changefreq>' + freq + '</changefreq>\n' if freq
        xml += '<priority>' + priority + '</priority>\n' if priority
        xml += '<lastmod>' + lastmod + '</lastmod>\n' if lastmod
        xml += '</url>\n'
        return xml

    _generatePublicWavesSitemap: (callback) ->
        ###
        Генерим sitemap из для публичных топиков
        ###
        @_logger.info("Generating public topics sitemap")
        @_sitemapBlipSearchController.searchPublicBlips((err, res) =>
            return callback(err, null) if err
            xml = @_generateUrlsetXmlHeader()
            maxMtime = null
            for wave in res
                lastMod = new Date(wave.groupdate * 1000)
                url = "#{@_publicTopicsBaseUrl}/#{wave.wave_url}/"
                xml += @_generateUrlXml(url, lastMod.toISOString(), 0.5, 'daily')
                maxMtime = lastMod if not maxMtime or lastMod.getTime() > maxMtime.getTime()
            xml += @_generateUrlsetXmlFooter()
            maxStat = if maxMtime then {atime: maxMtime, mtime: maxMtime} else null
            @_saveFile(path.join(@_dstPath, @_publicTopicsSitemapName), xml, maxStat)
            @_logger.info("#{res.length} items generated")
            callback(null, maxMtime)
        )

    _saveFile: (dstPath, content, stats) =>
        ###
        Save content in file
        ###
        fs.writeFileSync(dstPath, content)
        fs.utimesSync(dstPath, stats.atime, stats.mtime) if stats
        return dstPath

    _generatePagesSitemap: (callback) ->
        ###
        Генерим sitemap для статических страниц
        ###
        @_logger.info("Generating static pages sitemap")
        xml = @_generateUrlsetXmlHeader()
        count = 0
        xml += @_generateUrlXml(@_publicTopicsBaseUrl + '/', null, 0.7, 'monthly') # /topic/
        count++
        maxMtime = null
        files = fs.readdirSync(@_pagesPath)
        for file in files
            file = path.join(@_pagesPath, file)
            continue if file.indexOf('.html') != file.length - 5
            continue if file.indexOf('test') != -1
            stats = fs.statSync(file)
            continue if stats.size < HTML_SIZE_MIN_LIMIT
            url = file.replace(@_pagesPath, '')
            url = '' if url == 'index.html'
            xml += @_generateUrlXml("#{@_pagesBaseUrl}/#{url}", stats.mtime.toISOString(), 0.7, 'monthly')
            maxMtime = stats.mtime if not maxMtime or stats.mtime.getTime() > maxMtime.getTime()
            count++
        xml += @_generateUrlsetXmlFooter()
        maxStat = if maxMtime then {atime: maxMtime, mtime: maxMtime} else null
        @_saveFile(path.join(@_dstPath, @_pagesSitemapName), xml, maxStat)
        @_logger.info("#{count} items generated")
        callback(null, maxMtime)

    _generateSitemapIndex: (pagesMaxMtime, publicWavesMaxMtime, callback) ->
        ###
        Генерим индексный sitemap
        ###
        @_logger.info("Generating index sitemap")
        xml = '<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        xml += '<sitemap>\n'
        xml += "<loc>#{@_sitemapsBaseUrl}/#{@_pagesSitemapName}</loc>\n"
        xml += '<lastmod>' + pagesMaxMtime.toISOString() + '</lastmod>\n'
        xml += '</sitemap>\n'
        xml += '<sitemap>\n'
        xml += "<loc>#{@_sitemapsBaseUrl}/#{@_publicTopicsSitemapName}</loc>\n"
        xml += '<lastmod>' + publicWavesMaxMtime.toISOString() + '</lastmod>\n'
        xml += '</sitemap>\n'
        xml += '</sitemapindex>\n'
        maxMtime = if pagesMaxMtime.getTime() < publicWavesMaxMtime.getTime() then publicWavesMaxMtime else pagesMaxMtime
        maxStat = if maxMtime then {atime: maxMtime, mtime: maxMtime} else null
        @_saveFile(path.join(@_dstPath, @_sitemapIndexName), xml, maxStat)
        @_logger.info("2 items generated")
        callback(null, maxMtime)

    generate: (callback) ->
        ###
        Главный сайтмэпо всея проект генерящий метод
        ###
        if not fs.existsSync(@_dstPath)
            @_logger.info("Making sitemap folder")
            fs.mkdirSync(@_dstPath, 0755)
        tasks = [
            (callback) ->
                # грязный хак чтобы amqp успел подняться
                setTimeout(() ->
                    callback()
                , 5 * 1000)
            (callback) =>
                @_generatePagesSitemap(callback)
            (pagesMaxMtime, callback) =>
                @_generatePublicWavesSitemap((err, publicWavesMaxMtime) ->
                    callback(err, pagesMaxMtime, publicWavesMaxMtime)
                )
            (pagesMaxMtime, publicWavesMaxMtime, callback) =>
                @_generateSitemapIndex(pagesMaxMtime, publicWavesMaxMtime, callback)
        ]
        async.waterfall(tasks, (err) =>
            @_logger.error(err) if err
            callback(err)
        )


module.exports.Sitemap = new Sitemap()
