ck = window.CoffeeKup

marketPanelTmpl = ->
    ###
    Отрисовывает хидер и контейнер панели маркета
    ###
    div '.js-market-panel-header.market-panel-header', ->
        button '.js-market-items-filter.market-items-filter.pressed', {searchParam: 'All'}, 'All'
        button '.js-market-items-filter.market-items-filter', {searchParam: '1'}, 'Gadgets'
        button '.js-market-items-filter.market-items-filter', {searchParam: '2'}, 'Extensions'
    div '.js-market-panel-results.market-panel-results', ''

marketItem = ->
    ###
    Отрисовывает элемент панели маркета
    ###
    a ".js-market-panel-result.market-panel-result", {href: "#{h(@prefix)}#{h(@item.topicUrl)}", id: h(@item.htmlId), title: h(@item.title)}, ->
        div ".item-logo", {style: "background: url('#{@item.icon}') 0 0 no-repeat"}, ''
        div ".item-description#{if @item.category == 2 then '.extension' else ''}", ->
            span 'title', {title: h(@item.title)}, h(@item.title)
            br ''
            span '.snippet', {title: h(@item.description)}, h(@item.description)
        if @item.category == 1
            div '.market-chechbox', ->
                checked = if @item.state is 2 then 'checked' else ''
                input {type: 'checkbox', id: "#{h(@item.id)}", checked: checked}
                label '.js-gadget-checkbox-label', {for: "#{h(@item.id)}"}
        div '.clearer', ''

exports.renderPanelTmpl = ck.compile(marketPanelTmpl)

exports.renderResultItem = ck.compile(marketItem)