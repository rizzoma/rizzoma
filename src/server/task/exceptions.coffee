ExternalError = require('../common/exceptions').ExternalError

class InvalidTaskStatus extends ExternalError
    ###
    Ошибка 'неверный формат статуса задачи'.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'InvalidTaskStatus'
        @message = 'Invalid task status'

class TaskNotFound extends ExternalError
    ###
    Ошибка 'неверный формат статуса задачи'.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'TaskNotFound'
        @message = 'Task not found'

module.exports = {
    InvalidTaskStatus
    TaskNotFound
}
