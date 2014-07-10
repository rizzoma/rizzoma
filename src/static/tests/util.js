function Logger() {

}

Logger.prototype.init = function(parent) {
    if(!parent) parent = document.body;
    var container;
    this.container = container = document.createElement('div');
    this.clearBtn = container.appendChild(document.createElement('button'));
    this.clearBtn.textContent = 'clear';
    this.output = container.appendChild(document.createElement('div'));
    this.output.className = 'output';
    this.output.appendChild(document.createElement('br'));
    parent.appendChild(container);
    return this;
};

Logger.prototype.print = function(cls, args){
    if(this.output.lastChild && this.output.lastChild.tagName == 'BR') this.output.removeChild(this.output.lastChild);
    var container = document.createElement('div');
    container.className = cls;
    for(var i = 0; i < args.length; ++i){
        container.appendChild(document.createTextNode('|' + args[i] + '| '));
    }
    container.appendChild(document.createElement('br'));
    this.output.appendChild(container);
};

Logger.prototype.log = function(){
    this.print('logger-log', arguments);
};

Logger.prototype.warn = function(){
    this.print('logger-warn', arguments);
};

Logger.prototype.error = function(){
    this.print('logger-err', arguments);
};
