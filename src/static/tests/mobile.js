window.addEventListener('load', function(){start();}, false);

function removeClass(node, value){
    var className = (' ' + node.className + ' ').replace(/[\n\t\r]/g, ' ').replace(' ' + value + ' ', ' ').trim()
    if(className == node.className)return false;
    node.className = className
}

function addClass(node, value){
    var value = ' ' + value + ' '
    var className = (' ' + node.className + ' ')
    if(className.indexOf(value) != -1)return false;
    node.className = (className + value).trim()
}

function start(){
    var tabs = document.getElementsByClassName('js-tab-selector');
    for(var i = tabs.length - 1; i >= 0; --i){
        tabs[i].addEventListener('change', function(){
            var activeTab = document.getElementsByClassName('shown-content-tab')[0]
            if(activeTab)removeClass(activeTab, 'shown-content-tab')
            addClass(document.getElementById(this.id + '-content'), 'shown-content-tab')
        }, false)
    }
    setTimeout(function(){
        addClass(document.getElementById('tab-1-content'), 'shown-content-tab')
    }, 0)
    
}
