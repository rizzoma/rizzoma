CenteredWindow = require('./centered_window').CenteredWindow

class ModalWindow extends CenteredWindow
    ###
    Shows modal window over the page.
    ###
    __createDom: (params) ->
        super(params)
        $(@_container).addClass('modal')

exports.ModalWindow = ModalWindow
