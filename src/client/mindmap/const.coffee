###
Константы для отрисовки mindmap
###

module.exports.TEXT_NODE_HEIGHT = TEXT_NODE_HEIGHT = 21 # Высота текстовой ноды
module.exports.TEXT_Y_OFFSET = 15 # Смещение baseline'а текста в текстовой ноде
module.exports.TEXT_NODE_PADDING_LEFT = 10
module.exports.HEADER_OFFSET_X = 20
module.exports.HEADER_OFFSET_Y = 5
module.exports.ROOT_BLOCK_OFFSET_X = 30
module.exports.ROOT_BLOCK_OFFSET_Y = 30
module.exports.FOLD_BUTTON_WIDTH = 19
module.exports.FOLD_BUTTON_HEIGHT = FOLD_BUTTON_HEIGHT = 19
module.exports.FOLD_BUTTON_TOP_OFFSET = (TEXT_NODE_HEIGHT - FOLD_BUTTON_HEIGHT) / 2
module.exports.FOLD_BUTTON_LEFT_PADDING = 3
module.exports.SHORT_MAX_NODE_TEXT_LENGTH = 25
module.exports.LONG_MAX_NODE_TEXT_LENGTH = 75
module.exports.PIXELS_PER_SYMBOL = 7 # Примерное количество пикселей на символ в ширину, для примерного подсчета
module.exports.SHORT_MAX_THREAD_WIDTH = 240 # Ширина треда, если количество символов больше максимального допустимого
module.exports.LONG_MAX_THREAD_WIDTH = 550 # Ширина треда, если количество символов больше максимального допустимого
module.exports.ICO_WIDTH = 18
module.exports.ICO_HEIGHT = 14
module.exports.ICO_SIDE_PADDING = 1
module.exports.MINIMAL_THREAD_WIDTH = 30
module.exports.BLIP_SPACE = BLIP_SPACE = 6 # Расстояние между блипами в треде
module.exports.DESCRIPTION_LEFT_OFFSET = 100 # Отступ между правой границей треда и левой границей дочерних тредов
module.exports.DESCRIPTION_ARROW_HEIGHT = 10
module.exports.PARAGRAPH_LINE_LEFT_OFFSET = 4
module.exports.PARAGRAPH_LINE_HEIGHT = TEXT_NODE_HEIGHT - 4

# Параметры оформления корневого треда
module.exports.THREAD_DRAG_ZONE_HEIGHT = THREAD_DRAG_ZONE_HEIGHT = 21
module.exports.HIDDEN_THREAD_DRAG_ZONE_HEIGHT = THREAD_DRAG_ZONE_HEIGHT / 2 - BLIP_SPACE / 2 # Отступ на месте drag-зоны для тредов с одним блипом
module.exports.ROOT_BLIP_SPACE = ROOT_BLIP_SPACE = THREAD_DRAG_ZONE_HEIGHT + 1 # Расстояние между блипами в корневом треде
module.exports.DESCRIPTION_BLOCK_LINE_TOP_OFFSET = DESCRIPTION_BLOCK_LINE_TOP_OFFSET = -10
module.exports.DESCRIPTION_HEIGHT_LINE_TOP_OFFSET = DESCRIPTION_BLOCK_LINE_TOP_OFFSET + ROOT_BLIP_SPACE / 2
module.exports.DESCRIPTION_HEIGHT_LINE_LEFT_OFFSET = DESCRIPTION_HEIGHT_LINE_LEFT_OFFSET = -20
module.exports.DESCRIPTION_HEIGHT_LINE_WIDTH = DESCRIPTION_HEIGHT_LINE_WIDTH = 4
module.exports.DESCRIPTION_BLOCK_LINE_LEFT_OFFSET = DESCRIPTION_HEIGHT_LINE_LEFT_OFFSET + DESCRIPTION_HEIGHT_LINE_WIDTH / 2
module.exports.BLIP_DRAG_ZONE_WIDTH = 13
module.exports.BLIP_DRAG_ZONE_HEIGHT = 21
module.exports.THREAD_DRAG_ZONE_WIDTH = 23
# Количество пикселей с конца треда, в которые будут падать дочерние блипы
module.exports.DROP_CHILD_THREAD_ZONE = 20
module.exports.GHOST_X_OFFSET = 5
module.exports.GHOST_Y_OFFSET = 5
module.exports.GHOST_MAX_WIDTH = 1000 # Ширина призрака не ограничена
module.exports.GHOST_MAX_HEIGHT = 350 # Высота ограничена
module.exports.VIRTUAL_THREAD_LEFT_OFFSET = 10 # Отступ слева для виртуальных тредов
module.exports.VIRTUAL_THREAD_TOP_OFFSET = -7 # Отступ сверху для виртуальных тредов

module.exports.BLIP_BACKGROUND_REMOVE_TIMEOUT = 5000 # Время. через которое можно удалять анимированный background блипа
module.exports.BLIP_BACKGROUND_OFFSET = 4 # Отступ анимированного background'а блипа от края рамки