###
Утилиты для работы со строками общие для клиента и сервера.
###

isEmailRe = /^[-a-z0-9!#$%&'*+/=?^_`{|}~]+(?:\.[-a-z0-9!#$%&'*+/=?^_`{|}~]+)*@(?:[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?\.)*(?:aero|arpa|asia|biz|cat|com|coop|edu|gov|info|int|jobs|mil|mobi|museum|name|net|org|pro|tel|travel|[a-z][a-z])$/i
module.exports.isEmail = (str) ->
    isEmailRe.test(str)

exports.escapeHTML = (str) ->
    str.replace(/&/g,'&amp;')
        .replace(/>/g,'&gt;')
        .replace(/</g,'&lt;')
        .replace(/"/g,'&quot;')

strip = exports.strip = (str) ->
    str.replace(/^\s+|\s+$/g, '')

exports.normalizeEmail = (str) ->
    strip(str.toLowerCase())

class Utf16Util
    @REPLACEMENT_CHARACTER = String.fromCharCode(0xFFFD)
    @CHAR_TYPE =
        OK: 0
        BIDI: 1
        CONTROL: 2
        DEPRECATED: 3
        IGNORABLE: 4
        NONCHARACTER: 5
        SUPPLEMENTARY: 6
        SURROGATE: 7
        TAG: 8

    @isControl: (cp) ->
        ###
        Проверяет является ли codepoint упраляющим символом
        ###
        0 <= cp <= 0x1F or 0x7F <= cp <= 0x9F

    @isSurrogate: (cp) ->
        ###
        Проверяет является ли codepoint суррогатным символом (обязательно состоящим из пары)
        @param c: int - строка из одного символа
        @returns: boolean
        ###
        0xD800 <= cp <= 0xDFFF

    @isLowSurrogate: (cp) ->
        0xDC00 <= cp <= 0xDFFF

    @isHighSurrogate: (cp) ->
        0xD800 <= cp < 0xDC00

    @isSupplementary: (cp) ->
        ###
        Проверяет является ли codepoint символом в дополнительной таблице
        ###
        cp >= 0x10000

    @isCodePoint: (cp) ->
        ###
        Проверяет является ли аргумент codepoint'ом
        ###
        0 <= cp <= 0x10FFFF

    @isBidi: (cp) ->
        ###
        Проверяет является ли codepoint символом bidi формата
        ###
        # bidi neutral formatting
        return yes if cp is 0x200E or cp is 0x200F
        # bidi general formatting
        0x202A <= cp <= 0x202E

    @isDefaultIgnorable: (cp) ->
        # not included: bidirectional format controls (e.g. U+200E LEFT-TO-RIGHT MARK)
        switch cp
            when 0x200C, 0x200D then yes # cursive joiners
            when 0x00AD then yes # the soft hyphen
            when 0x2060, 0xFEFF then yes # word joiners
            when 0x200B then yes # the zero width space
            when 0x2061, 0x2062, 0x2063, 0x2064 then yes # invisible math operators
            when 0x115F, 0x1160 then yes # Jamo filler characters
            else no

    @isOtherDefaultIgnorable: (cp) ->
        return yes if cp is 0xFF00
        return yes if 0xFFA0 <= cp <= 0xFFDF
        return yes if 0xFFE7 <= cp <= 0xFFEF
        no

    @isDeprecated: (cp) ->
        0x206A <= cp <= 0x206F

    @isValid: (cp) ->
        ###
        Проверяет валидность символа
        @param cp: int - строка из одного символа
        @returns: boolean - true, если символ валидный, false, если это non-character символ
        ###
        return no if not @isCodePoint(cp)
        d = cp & 0xFFFF
        # never to change noncharacters
        return no if d is 0xFFFE or d is 0xFFFF
        return no if 0xFDD0 <= cp <= 0xFDEF
        yes

    @getCharType: (c) ->
        cp = c.charCodeAt(0)
        return @CHAR_TYPE.NONCHARACTER if not @isValid(cp)
        return @CHAR_TYPE.CONTROL if @isControl(cp)
        return @CHAR_TYPE.SURROGATE if @isSurrogate(cp)
        return @CHAR_TYPE.IGNORABLE if @isDefaultIgnorable(cp)

#        // private use
#        // we permit these, they can be used for things like emoji
#        //if (0xE000 <= c && c <= 0xF8FF) { return false; }
#        //if (0xF0000 <= c && c <= 0xFFFFD) { return false; }
#        //if (0x100000 <= c && c <= 0x10FFFD) { return false; }

#        The No-Break Space (U+00A0) also produces a baseline advance without a glyph but inhibits rather than enabling a line-break.

#        interlinear annotation chars
#        script-specific

        return @CHAR_TYPE.DEPRECATED if @isDeprecated(cp)
#        // TODO: investigate whether we can lift some of these restrictions
#        // bidi markers
        return @CHAR_TYPE.BIDI if @isBidi(cp)
#        // tag characters, strongly discouraged
#        if (0xE0000 <= c && c <= 0xE007F) { return BlipCodePointResult.TAG; }
        return @CHAR_TYPE.SUPPLEMENTARY if @isSupplementary(cp)
        @CHAR_TYPE.OK;

    @unpairedSurrogate: (c) ->
        Utf16Util.REPLACEMENT_CHARACTER

    @traverseString: (str) ->
        ###
        Traverse UTF16 string
        ###
        res = ''
        for c, i in str
            switch @getCharType(c)
                when @CHAR_TYPE.OK
                    res += c
                when @CHAR_TYPE.CONTROL, @CHAR_TYPE.BIDI, @CHAR_TYPE.DEPRECATED, @CHAR_TYPE.IGNORABLE
                    continue
                else
                    res += @REPLACEMENT_CHARACTER
        res

exports.Utf16Util = exports.StringUtil = Utf16Util

colonDoubleSlashScheme = [
    'ftp',
    'https?',
    'gopher',
    'telnet'
]

colonScheme = [
    'mailto',
    'tel',
    'skype'
]

urlRegExp = ///
    (((#{colonScheme.join('|')}):) | ((#{colonDoubleSlashScheme.join('|')})://))
    [^\s]+
    ([^\(\)\{\}\[\],\.;:'\"\s])
///ig

exports.matchUrls = (str) ->
    urlRegExp.lastIndex = 0
    while exec = urlRegExp.exec(str)
        index = exec.index
        if index and str.charAt(index - 1).match(/[a-z0-9]/i)
            urlRegExp.lastIndex = index + 1
            continue
        {startIndex: index, endIndex: urlRegExp.lastIndex}

exports.ucfirst = (str) ->
    return str.charAt(0).toUpperCase() + str.substr(1, str.length-1)

exports.toCamelCase = (str) ->
    parts = str.split(/\-|_/)
    return (exports.ucfirst(part) for part in parts).join('')
