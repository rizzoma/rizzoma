SessionView = require('./view').SessionViewMobile

class Session
    setAsLoggedIn: ->
        SessionView.hide()
  
    setAsLoggedOut: ->
        SessionView.show()
        
module.exports.Session = new Session()
