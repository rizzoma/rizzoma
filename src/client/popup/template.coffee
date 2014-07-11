ck = window.CoffeeKup

popupTmpl = ->
    div '.js-popup-menu-container.popup-menu-container', ->
        div '.js-internal-container', ->
            div ''

gadgetPopupTmpl = ->
    div '.js-gadget-popup-menu-container.popup-menu-container', ->
        div '.js-internal-container', ->
            div ''

exports.renderPopup = ck.compile(popupTmpl)
exports.renderGadgetPopup = ck.compile(gadgetPopupTmpl)