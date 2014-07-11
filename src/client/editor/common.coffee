class EventType
    # Ввод содержимого
    @INPUT = 'INPUT'
    # Перемещения курсора
    @NAVIGATION = 'NAVIGATION'
    # Удаление содержимого
    @DELETE = 'DELETE'
    # Новый параграф
    @LINE = 'LINE'
    # Увеличение уровня списка
    @TAB = 'TAB'
    # Опасные, которые могут внести изменения
    @DANGEROUS = 'DANGEROUS'
    # Остальные, не вносящие изменений
    @NOEFFECT = 'NOEFFECT'

exports.EventType = EventType
exports.SPECIAL_INPUT = {'@': 'insertRecipient', '#': 'insertTag', '~': 'insertTaskRecipient'}
exports.MAX_URL_LENGTH = 8 * 1024
