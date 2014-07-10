# Category: mouse

exports.CLICK_EVENT = CLICK_EVENT = 'click'
exports.MOUSE_DOWN_EVENT = MOUSE_DOWN_EVENT = 'mousedown'
exports.MOUSE_UP_EVENT = MOUSE_UP_EVENT = 'mouseup'
exports.MOUSE_EVENTS = [
    CLICK_EVENT,
    'dblclick',
    MOUSE_DOWN_EVENT,
    MOUSE_UP_EVENT,
    'mouseover',
    'mousemove',
    'mouseout',
    'mousewheel',
    'contextmenu',
    'selectstart'
]

# Category: touch
exports.TOUCH_START_EVENT = 'touchstart'
exports.TOUCH_MOVE_EVENT = 'touchmove'
exports.TOUCH_END_EVENT = 'touchend'
exports.TOUCH_CANCEL_EVENT = 'touchcancel'

# Category: key
exports.KEY_DOWN_EVENT = KEY_DOWN_EVENT = 'keydown'
exports.KEY_PRESS_EVENT = KEY_PRESS_EVENT = 'keypress'
exports.KEY_UP_EVENT = KEY_UP_EVENT = 'keyup'
exports.KEY_EVENTS = [
    KEY_DOWN_EVENT,
    KEY_PRESS_EVENT,
    KEY_UP_EVENT
]

# Category: dragdrop
exports.DRAG_EVENT = DRAG_EVENT = 'drag'
exports.DRAG_START_EVENT = DRAG_START_EVENT = 'dragstart'
exports.DRAG_ENTER_EVENT = DRAG_ENTER_EVENT = 'dragenter'
exports.DRAG_OVER_EVENT = DRAG_OVER_EVENT = 'dragover'
exports.DRAG_LEAVE_EVENT = DRAG_LEAVE_EVENT = 'dragleave'
exports.DRAG_END_EVENT = DRAG_END_EVENT = 'dragend'
exports.DROP_EVENT = DROP_EVENT = 'drop'
exports.DRAGDROP_EVENTS = [
    DRAG_EVENT,
    DRAG_START_EVENT,
    DRAG_ENTER_EVENT,
    DRAG_OVER_EVENT,
    DRAG_LEAVE_EVENT,
    DRAG_END_EVENT,
    DROP_EVENT
]

# Category: clipboard
exports.COPY_EVENT = COPY_EVENT = 'copy'
exports.CUT_EVENT = CUT_EVENT = 'cut'
exports.PASTE_EVENT = PASTE_EVENT = 'paste'
exports.BEFORE_CUT_EVENT = BEFORE_CUT_EVENT = 'beforecut'
exports.BEFORE_COPY_EVENT = BEFORE_COPY_EVENT = 'beforecopy'
exports.BEFORE_PASTE_EVENT = BEFORE_PASTE_EVENT = 'beforepaste'
exports.CLIPBOARD_EVENTS = [
    CUT_EVENT,
    COPY_EVENT,
    PASTE_EVENT,
]

# Category: focus
exports.BLUR_EVENT = BLUR_EVENT = 'blur'
exports.FOCUS_EVENT = FOCUS_EVENT = 'focus'
exports.FOCUS_EVENTS = [
    FOCUS_EVENT,
    BLUR_EVENT,
    'beforeeditfocus'
]

# Category: mutation
exports.DOM_FOCUS_IN = 'DOMFocusIn'
exports.DOM_FOCUS_OUT = 'DOMFocusOut' 
exports.DOM_NODE_INSERTED = 'DOMNodeInserted'
exports.DOM_NODE_REMOVED = 'DOMNodeRemoved'
exports.MUTATION_EVENTS = [
    'DOMActivate',
    'DOMAttributeNameChanged',
    'DOMAttrModified',
    'DOMCharacterDataModified',
    'DOMElementNameChanged',
    exports.DOM_FOCUS_IN,
    exports.DOM_FOCUS_OUT,
    'DOMMouseScroll',
    exports.DOM_NODE_INSERTED,
    'DOMNodeInsertedIntoDocument',
    exports.DOM_NODE_REMOVED,
    'DOMNodeRemovedFromDocument',
    'DOMSubtreeModified'
]

#/** IME composition commencement event */
exports.COMPOSITION_START_EVENT = COMPOSITION_START_EVENT = "compositionstart";

#/** IME composition completion event */
exports.COMPOSITION_END_EVENT = COMPOSITION_END_EVENT = "compositionend";

#/** DOM level 3 composition update event */
exports.COMPOSITION_UPDATE_EVENT = COMPOSITION_UPDATE_EVENT = "compositionupdate";

#/** Firefox composition update event */
exports.TEXT_EVENT = TEXT_EVENT = "text";
exports.INPUT_EVENT = 'input'

#/** Poorly supported DOM3 event */
exports.TEXT_INPUT_EVENT = TEXT_INPUT_EVENT = 'textInput';
exports.INPUT_EVENTS = [
    ## Category: input
    COMPOSITION_START_EVENT,  # IME events
    COMPOSITION_END_EVENT,    # IME events
    COMPOSITION_UPDATE_EVENT, # IME events
    TEXT_EVENT,        # IME events
    TEXT_INPUT_EVENT,  # In supported browsers, fired both for IME and non-IME input
]
#/**
#* Array of events the editor listens for
#*/
exports.OTHER_EVENTS = [

## Category: frame/object",
  "load",
  "unload",
  "abort",
  "error",
  "resize",
  "scroll",
  "beforeunload",
  "stop",

## Category: form",
  "select",
  "change",
  "submit",
  "reset",

## Category: ui",
  "domfocusin",
  "domfocusout",
  "domactivate",

## Category: data binding",
  "afterupdate",
  "beforeupdate",
  "cellchange",
  "dataavailable",
  "datasetchanged",
  "datasetcomplete",
  "errorupdate",
  "rowenter",
  "rowexit",
  "rowsdelete",
  "rowinserted",

## Category: misc",
  "help",

  "start",  #marquee
  "finish", #marquee
  "bounce", #marquee

  "beforeprint",
  "afterprint",

  "propertychange",
  "filterchange",
  "readystatechange",
  "losecapture"
]

exports.C_FOCUS_EVENT = 'c_focus'
exports.C_BLIP_CREATE_EVENT = 'c_blip_create_event'
exports.C_BLIP_INSERT_EVENT = 'c_blip_insert_event'
exports.C_EDITOR_MOUSE_DOWN_EVENT = 'c_editor_mouse_down'
exports.C_READ_ALL_EVENT = 'c_read_all'

blockEvent = exports.blockEvent = (event) ->
    event.stopPropagation()
    event.preventDefault()

createEvent = (type, name, bubbles, cancelable) ->
    # From IE 9 only
    e = document.createEvent(type)
    e.initEvent(name, bubbles, cancelable)
    e

createTouchEvent = (name, bubbles, cancelable) ->
    # From IE 9 only
    e = document.createEvent('TouchEvent')
    e.initTouchEvent(name, bubbles, cancelable)
    if e.type isnt name
        e.initUIEvent(name, bubbles, cancelable)
    e

stopEventPropagation = (event) ->
    event.stopPropagation()

exports.addBlocker = (element, type, capture = no) ->
    element.addEventListener(type, blockEvent, capture)

exports.removeBlocker = (element, type, capture = no) ->
    element.removeEventListener(type, blockEvent, capture)

exports.addPropagationBlocker = (element, type, capture = no) ->
    element.addEventListener(type, stopEventPropagation, capture)

exports.removePropagationBlocker = (element, type, capture = no) ->
    element.removeEventListener(type, stopEventPropagation, capture)

exports.createCustomEvent = (name, bubbles, cancelable) ->
    createEvent('Event', name, bubbles, cancelable)

exports.createTouchEvent = (name, bubbles, cancelable) ->
    createTouchEvent(name, bubbles, cancelable)
