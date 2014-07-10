ck = window.CoffeeKup

contributorTmpl = ->
    span '.contributor.avatar', {style:"background-image: url(#{h(@avatar)})"}, h(@initials)

contributorsContainerTmpl = ->
    div '.js-contributors-container.contributors', ''

authorTmpl = ->
    div '.shown-contributor.back-contributor.avatar', {style:"background-image: url(#{h(@users[1].avatar)})"}, h(@users[1].initials) if @users[1]
    div '.shown-contributor.js-shown-contributor-avatar.avatar', {style:"background-image: url(#{h(@users[0].avatar)})"}, h(@users[0].initials)

exports.renderContributor = ck.compile(contributorTmpl)

exports.renderContributorsContainer = ck.compile(contributorsContainerTmpl)

exports.renderAuthor = ck.compile(authorTmpl)
