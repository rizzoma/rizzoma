DomUtils = require('../utils/dom')

class CachedRange
    constructor: (@_editor, @_startElement, @_startOffset, @_startIndex, @_endElement, @_endOffset, @_endIndex) ->
        @setAsNotChanged()

    isCollapsed: ->
        @_startIndex is @_endIndex

    getStartElement: ->
        @_startElement

    getStartOffset: ->
        @_startOffset

    getStartIndex: ->
        @_startIndex

    getEndElement: ->
        @_endElement

    getEndOffset: ->
        @_endOffset

    getEndIndex: ->
        @_endIndex

    collapse: (toStart = no) ->
        if toStart
            @_endElement = @_startElement
            @_endOffset = @_startOffset
            @_endIndex = @_startIndex
        else
            @_startElement = @_endElement
            @_startOffset = @_endOffset
            @_startIndex = @_endIndex

    setStart: (element, offset, index) ->
        @_startElement = element
        @_startOffset = offset
        @_startIndex = index

    setEnd: (element, offset, index) ->
        @_endElement = element
        @_endOffset = offset
        @_endIndex = index

    setCursor: (args...) ->
        @setStart(args...)
        @setEnd(args...)

    shiftStart: (offset) ->
        @setAsChanged()
        @_startOffset += offset
        @_startIndex += offset

    shiftEnd: (offset) ->
        @setAsChanged()
        @_endOffset += offset
        @_endIndex += offset

    shiftStartIndex: (offset) ->
        @_startIndex += offset

    shiftEndIndex: (offset) ->
        @_startIndex += offset

    setAsChanged: ->
        @_changed = yes

    setAsNotChanged: ->
        @_changed = no

    processSplitText: (element, newElement, index) ->
        @setAsChanged()
        if @_endElement is element and index < @_endOffset
            @setEnd(newElement, @_endOffset - index, @_endIndex)
            return @collapse() if @isCollapsed()
        if @_startElement is element and index < @_startOffset
            @setStart(newElement, @_startOffset - index, @_startIndex)

    processInsertText: (element, offset, length, index) ->
        @setAsChanged()
        wasCollapsed = @isCollapsed()
        if @_endElement is element and @_endOffset > offset
            @shiftEnd(length)
            return @collapse() if wasCollapsed
        else if index < @_endIndex
            @_endIndex += length
            return @collapse() if wasCollapsed
        if @_startElement is element
            if @_startOffset is offset and not wasCollapsed
                @shiftStart(length)
            else if @_startOffset > offset
                @shiftStart(length)
        else if index < @_startIndex
            @_startIndex += length

    processInsertElement: (index, length) ->
        @setAsChanged()
        wasCollapsed = @isCollapsed()
        shiftEnd = if @_endOffset then 0 else 1
        if index < @_endIndex + shiftEnd
            @_endIndex += length
            return @_startIndex = @_endIndex if wasCollapsed
        shiftStart = if @_startOffset then 0 else 1
        @_startIndex += length if index < @_startIndex + shiftStart

    processDeleteElement: (index, element, length, prevElement, prevElementLength) ->
        @setAsChanged()
        wasCollapsed = @isCollapsed()
        if element is @_startElement
            @setStart(prevElement, prevElementLength, index)
        else if index < @_startIndex
            @_startIndex -= length
        return @collapse(yes) if wasCollapsed
        if element is @_endElement
            @setEnd(prevElement, prevElementLength, index)
        else if index < @_endIndex
            @_endIndex -= length

    processReplaceElement: (oldElement, newElement) ->
        @setAsChanged()
        @_startElement = newElement if @_startElement is oldElement
        @_endElement = newElement if @_endElement is oldElement

    processInsertedStart: (index, length) ->
        @setAsChanged()
        @_startIndex += length if index < @_startIndex

    processInsertedEnd: (index, length) ->
        @setAsChanged()
        @_endIndex += length if index < @_endIndex

    isChanged: ->
        @_changed

exports.CachedRange = CachedRange
