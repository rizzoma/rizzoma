class ParsedMail
    ###
    Класс разпарсенного письма с инте5ресующими нас полями
    ###
    constructor: (@from, @waveUrl, @blipId, @random, @text, @html, @headers) ->

    getId: () ->
        ###
        Возвращает "уникальный" ключ письма
        ###
        return "#{@waveUrl}/#{@blipId}/#{@random}/#{@headers.date}"

module.exports.ParsedMail = ParsedMail