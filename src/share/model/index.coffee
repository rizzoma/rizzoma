class ObjectParams
    @isValid: (param) ->
        ###
        Проверяет, что указанный параметр присутствует в данном наборе параметров
        @param param: any
        @return: boolean
        ###
        return no unless typeof(param) is 'string'
        # RANDOM необходим для идентификации параграфов, __RANDOM некоторое время создавался по ошибке
        return yes if param in ['RANDOM', '__RANDOM']
        return no unless param.substring(0, 2) is @_prefix
        return yes if @.hasOwnProperty(param.substring(2))
        no

class TextLevelParams extends ObjectParams
    ###
    Список поддерживаемых текстовых параметров
    Соглашение имен: для проверки важно ставить значения параметров равному имени параметра с префиксом 'T_'
    ###
    @_prefix: 'T_'
    @URL: 'T_URL'
    @BOLD: 'T_BOLD'
    @ITALIC: 'T_ITALIC'
    @STRUCKTHROUGH: 'T_STRUCKTHROUGH'
    @UNDERLINED: 'T_UNDERLINED'
    @BG_COLOR: 'T_BG_COLOR'

class LineLevelParams extends ObjectParams
    ###
    Список поддерживаемых текстовых параметров
    Соглашение имен: для проверки важно ставить значения параметров равному имени параметра с префиксом 'L_'
    ###
    @_prefix: 'L_'
    @BULLETED: 'L_BULLETED'
    @NUMBERED: 'L_NUMBERED'

class ModelField
    @PARAMS: 'params'
    @TEXT: 't'

class ParamsField
    @TEXT: '__TEXT'
    @TYPE: '__TYPE'
    @ID: '__ID'
    @URL: '__URL'
    @MIME: '__MIME'
    @SIZE: '__SIZE'
    @THUMBNAIL: '__THUMBNAIL'
    @USER_ID: '__USER_ID'
    @NAME: '__NAME'
    @RANDOM: 'RANDOM'
    @TAG: '__TAG'
    @THREAD_ID: '__THREAD_ID'

class ModelType
    @TEXT: 'TEXT'
    @BLIP: 'BLIP'
    @LINE: 'LINE'
    @ATTACHMENT: 'ATTACHMENT'
    @RECIPIENT: 'RECIPIENT'
    @TASK_RECIPIENT: 'TASK'
    @GADGET: 'GADGET'
    @FILE: 'FILE'
    @TAG: 'TAG'


exports.TextLevelParams = TextLevelParams
exports.LineLevelParams = LineLevelParams
exports.ModelField = ModelField
exports.ParamsField = ParamsField
exports.ModelType = ModelType
