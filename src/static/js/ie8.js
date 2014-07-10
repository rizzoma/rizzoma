Array.prototype.indexOf = function(elementToSearch, fromIndex){
    if(!fromIndex) fromIndex = 0;
    var length = this.length;
    for(var i = fromIndex; i < length; i++){
        if(this[i] == elementToSearch) return i;
    }
    return -1;
};

String.prototype.trim = function(){
    var s = this.replace(/^[ ]+/, '');
    return s.replace(/[ ]+$/, '');
};

Node = {
    DOCUMENT_POSITION_DISCONNECTED : 0x0001,
    DOCUMENT_POSITION_PRECEDING: 0x0002,
    DOCUMENT_POSITION_FOLLOWING: 0x0004,
    DOCUMENT_POSITION_CONTAINS: 0x0008,
    DOCUMENT_POSITION_CONTAINED_BY: 0x0010,
    DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 0x0020
};

Window.prototype.addEventListener = Element.prototype.addEventListener = HTMLDocument.prototype.addEventListener = function(type, func, capture){
    if(!type || !func) return;
    if(capture && this.setCapture) this.setCapture();
    if(!this.bindFunctions) {
        this.bindFunctions = {};
        this.realFunctions = {};
    }
    if(!this.bindFunctions[type]) {
        this.bindFunctions[type] = [];
        this.realFunctions[type] = [];
    }
    var f = function(e){
        Object.defineProperty(e, 'target', {
            get: function() {
                return e.srcElement;
            }
        });
        func.call(this, e)
    };
    this.bindFunctions[type].push(f);
    this.realFunctions[type].push(func);
    this.attachEvent('on' + type, f);
};

Window.prototype.removeEventListener = Element.prototype.removeEventListener = HTMLDocument.prototype.removeEventListener = function(type, func, capture){
    if(!type || !func || !this.bindFunctions || !this.bindFunctions[type]) return;
    var bindFunctions = this.bindFunctions[type];
    var realFunctions = this.realFunctions[type];
    var index = realFunctions.indexOf(func);
    if(index == -1) return;
    this.detachEvent('on' + type, bindFunctions[index], capture);
    bindFunctions.splice(index, 1);
    realFunctions.splice(index, 1);
};

Window.prototype.getSelection = function(){
    return null;
};

Element.prototype.getElementsByClassName = function(className) {
    return $(this).find('.' + className);
};

Date.now = function(){
    return +new Date();
};

Date.prototype.toISOString = function(){
    function f(n) {
        return n < 10 ? '0' + n : n;
    }
    return '"' + this.getUTCFullYear()   + '-' +
        f(this.getUTCMonth() + 1) + '-' +
        f(this.getUTCDate())      + 'T' +
        f(this.getUTCHours())     + ':' +
        f(this.getUTCMinutes())   + ':' +
        f(this.getUTCSeconds())   + 'Z"';
};

Event.prototype.stopPropagation = function(){
    this.cancelBubble = true;
};

Event.prototype.preventDefault = function(){
    this.returnValue = false;
};

