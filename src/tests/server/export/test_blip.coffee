testCase = require('nodeunit').testCase

BlipExportMarkupBuilder = require('../../../server/export/blip').BlipExportMarkupBuilder

getNode = (text='', params={}) ->
    return {t: text, params: params}
    
module.exports =
    BlipExportMarkupBuilderTest: testCase

        setUp: (callback) ->
            @_builder = new BlipExportMarkupBuilder()
            callback()

        testHandleLineIfUnorderedList: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_BULLETED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_BULLETED: 0}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'unordered', level: 0, nodes: [
                    {type: 'listItem', nodes: []}
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()

        testHandleLineIfTwoUnorderedLists: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_BULLETED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_BULLETED: 1}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'unordered', level: 0, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'unordered', level: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()

        testHandleLineIfOrderedList: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()

        testHandleLineIfOrderedListBrokenByLine: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode(''))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'paragraph', nodes: []}
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()
            
        testHandleLineIfOrderedListBrokenByUnorderedList: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_BULLETED: 1}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'unordered', level: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()
            
        testHandleLineIfOrderedListBrokenByOrderedList: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 1}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 1, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 0, start: 2, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()

        testHandleLineIfOrderedListBrokenByOrderedListButNotViceVersa: (test) ->
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 1}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 0}))
            @_builder.handleBlock('LINE', getNode('', {L_NUMBERED: 1}))
            result = @_builder.build()
            test.deepEqual(result.nodes, [
                {type: 'list', subtype: 'ordered', level: 0, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 1, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 0, start: 2, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
                {type: 'list', subtype: 'ordered', level: 1, start: 1, nodes: [
                    {type: 'listItem', nodes: []}
                ]}
            ])
            test.done()
            
        testGetTextNode: (test) ->
            result = @_builder._getTextNode({t: 'foobar', params: {T_BOLD: true, T_ITALIC: true}})
            test.deepEqual(result,
                {type: 'text', bold: true, nodes: [
                    {type: 'text', italic: true, nodes: [
                        {type: 'text', value: 'foobar'}
                    ]}
                ]}
            )
            test.done()
            
        testCompareNodesIfSame: (test) ->
            result = @_builder._compareNodes({url: 'foo'}, {url: 'foo'})
            test.ok(result == true)
            test.done()

        testCompareNodesIfDifferent: (test) ->
            result = @_builder._compareNodes({italic: true}, {})
            test.ok(result == false)
            test.done()

        testHandleTextIfLinkOfTwoParts: (test) ->
            ###
            Одна часть ссылки зачеркнута, другая - жирная.
            ###
            @_builder.handleBlock('LINE', getNode())
            @_builder.handleBlock('TEXT', getNode('one', {'T_URL': 'url', 'T_STRUCKTHROUGH': true}))
            @_builder.handleBlock('TEXT', getNode('two', {'T_URL': 'url', 'T_BOLD': true}))
            result = @_builder.build()
            test.deepEqual(result.nodes[0].nodes, [
                {type: 'text', url: 'url', nodes: [
                    {type: 'text', struckthrough: true, nodes: [
                        {type: 'text', value: 'one'}
                    ]}
                    {type: 'text', bold: true, nodes: [
                        {type: 'text', value: 'two'}
                    ]}
                ]}
            ])
            test.done()
            
        testHandleTextIfDifferentLinks: (test) ->
            ###
            Рядом стоят две разных ссылки и не сливаются.
            ###
            @_builder.handleBlock('LINE', getNode())
            @_builder.handleBlock('TEXT', getNode('one', {'T_URL': 'url1'}))
            @_builder.handleBlock('TEXT', getNode('two', {'T_URL': 'url2'}))
            result = @_builder.build()
            test.deepEqual(result.nodes[0].nodes, [
                {type: 'text', url: 'url1', nodes: [
                    {type: 'text', value: 'one'}
                ]}
                {type: 'text', url: 'url2', nodes: [
                    {type: 'text', value: 'two'}
                ]}
            ])
            test.done()
            
        testHandleTextIfTextAndLinkStruckthrough: (test) ->
            ###
            Ссылка перечеркнута вместе с другим текстом.
            ###
            @_builder.handleBlock('LINE', getNode())
            @_builder.handleBlock('TEXT', getNode('one', {'T_STRUCKTHROUGH': true}))
            @_builder.handleBlock('TEXT', getNode('two', {'T_STRUCKTHROUGH': true, 'T_URL': 'url'}))
            @_builder.handleBlock('TEXT', getNode('foo', {'T_STRUCKTHROUGH': true}))
            result = @_builder.build()
            test.deepEqual(result.nodes[0].nodes, [
                {type: 'text', struckthrough: true, nodes: [
                    {type: 'text', value: 'one'}
                ]}
                {type: 'text', url: 'url', nodes: [
                    {type: 'text', struckthrough: true, nodes: [
                        {type: 'text', value: 'two'}
                    ]}
                ]}
                {type: 'text', struckthrough: true, nodes: [
                    {type: 'text', value: 'foo'}
                ]}
            ])
            test.done()
    
        testHandleBlockIfThreadBeginsAndEnds: (test) ->
            ###
            Поток из блипов начинается и заканчивается.
            ###
            @_builder.handleBlock('LINE', getNode())
            @_builder.handleBlock('BLIP', getNode('', {'__ID': 'blip1'}))
            @_builder.handleBlock('BLIP', getNode('', {'__ID': 'blip2'}))
            @_builder.handleBlock('LINE', getNode())
            result = @_builder.build()
            test.deepEqual(result.nodes[0].nodes, [
                {type: 'thread', folded: false, nodes: [
                    {type: 'reply', id: 'blip1'}
                    {type: 'reply', id: 'blip2'}
                ]}
            ])
            test.done()
