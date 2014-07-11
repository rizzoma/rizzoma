sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
ImportSourceParser = require('../../../server/import/source_parser').ImportSourceParser
LINK_REDIRECT_PREFIX = require('../../../server/import/source_parser').LINK_REDIRECT_PREFIX
WaveGenerator = require('../../../server/wave/generator').WaveGenerator
BlipGenerator = require('../../../server/blip/generator').BlipGenerator
UserCouchProcessor = require('../../../server/user/couch_processor').UserCouchProcessor
waveCts = require('../../../server/wave/constants')
CouchImportProcessor = require('../../../server/import/couch_processor').CouchImportProcessor

module.exports =
    ImportSourceParserTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testParse: (test) ->
            source = 'the source string'
            sourceObj = {
                
            }
            wave = {
                id: 'waveId'
            }
            blips = [{
                id: 'blipId'
                isRootBlip: false
            }, {
                id: 'rootBlipId'
                isRootBlip: true
            }]
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('sourceToObject')
                .withExactArgs(source)
                .once()
                .returns(sourceObj)
            ImportSourceParserMock
                .expects('_parseWave')
                .withArgs(null, sourceObj)
                .once()
                .callsArgWith(2, null, wave)
            ImportSourceParserMock
                .expects('_parseBlips')
                .withArgs(sourceObj, wave, null)
                .once()
                .callsArgWith(3, null, blips)
            ImportSourceParser.parse(null, source, null, (err, resWave, resBlips) ->
                test.equal(null, err)
                test.equal(wave, resWave)
                test.equal('rootBlipId', resWave.rootBlipId)
                test.equal(blips, resBlips)
                
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_parseWave: (test) ->
            code = (done, expSharedState, participants) ->
                sourceObj = [{
                    data: {
                        waveletData: {
                            participants: participants
                        }
                    }
                }]
                waveId = 'waveId'
                WaveGeneratorMock = sinon.mock(WaveGenerator)
                WaveGeneratorMock
                    .expects('getNext')
                    .callsArgWith(0, null, waveId)
                    .once()
                ImportSourceParserMock = sinon.mock(ImportSourceParser)
                ImportSourceParserMock
                    .expects('_parseWaveParticipants')
                    .withArgs(sourceObj[0].data.waveletData)
                    .callsArgWith(1, null, 'participants')
                    .once()
                ImportSourceParser._parseWave(null, sourceObj, (err, resWave) ->
                    test.equal('participants', resWave.participants)
                    test.equal(waveId, resWave.id)
                    test.equal(expSharedState, resWave.sharedState)
                    sinon.verifyAll()
                    sinon.restoreAll()
                    done()
                )
            dataprovider(test, [
                [waveCts.WAVE_SHARED_STATE_PRIVATE, ['sdf@gmail.com']]
                [waveCts.WAVE_SHARED_STATE_PRIVATE, ['public@a.gwave.com']]
            ],code)
            
        test_normalizeEmail: (test) ->
            code = (done, exp, email) ->
                test.equal(exp, ImportSourceParser._normalizeEmail(email))
                done()
            dataprovider(test, [
                ['test@gmail.com', 'test@googlewave.com']
                ['test@example.com', 'test@example.com']
            ],code)
            
        test_parseWaveParticipants: (test) ->
            waveletData = {
                participantRoles: {
                    'p1@googlewave.com': 'FULL'
                    'p2@googlewave.com': 'НЕ FULL'
                    'p3@googlewave.com': 'FULL'
                    'p4@example.com': 'НЕ FULL'
                }
            }
            UserProcessorMock = sinon.mock(UserCouchProcessor)
            UserProcessorMock
                .expects('getOrCreateByEmails')
                .once()
                .callsArgWith(1, null, {
                    'p1@gmail.com': { id: '0_user_1'}
                    'p2@gmail.com': { id: '0_user_2'}
                    'p3@gmail.com': { id: '0_user_3'}
                    'p4@example.com': { id: '0_user_4'}
                })
            ImportSourceParser._parseWaveParticipants(waveletData, (err, participants) ->
                test.deepEqual([
                    { id: '0_user_1', role: waveCts.WAVE_ROLE_MODERATOR}
                    { id: '0_user_2', role: waveCts.WAVE_ROLE_READER}
                    { id: '0_user_3', role: waveCts.WAVE_ROLE_MODERATOR}
                    { id: '0_user_4', role: waveCts.WAVE_ROLE_READER}
                ], participants)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testGenerateBlipIds: (test) ->
            blipsData = {
                'GWaveBlipId1': {}
                'GWaveBlipId2': {}
            }
            BlipGeneratorMock = sinon.mock(BlipGenerator)
            BlipGeneratorMock
                .expects('getNextRange')
                .once()
                .withArgs('0_w_1', 2)
                .callsArgWith(2, null, ['blipId2', 'blipId1'])
            ImportSourceParser.generateBlipIds('0_w_1', blipsData, (err, blipIds) ->
                test.deepEqual({
                    'GWaveBlipId1': 'blipId1'
                    'GWaveBlipId2': 'blipId2'
                }, blipIds)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_parseBlips: (test) ->
            wave = {
                id: "waveId"
            }
            sourceObj = [{
                data: {
                    blips: {
                        'GWaveBlipId1': {
                            
                        },
                        'GWaveBlipId2': {
                            
                        }
                    }
                }
            }]
            sourceData = sourceObj[0].data
            blipsData = sourceData.blips
            blipIds = {
                'GWaveBlipId1': 'blipId1'
                'GWaveBlipId2': 'blipId2'
            }
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('generateBlipIds')
                .once()
                .callsArgWith(2, null, blipIds)
            ImportSourceParserMock
                .expects('_parseBlip')
                .withArgs(wave, blipsData['GWaveBlipId1'], sourceData, blipIds)
                .once()
                .callsArgWith(4, null, 'blip1')
            ImportSourceParserMock
                .expects('_parseBlip')
                .withArgs(wave, blipsData['GWaveBlipId2'], sourceData, blipIds)
                .once()
                .callsArgWith(4, null, 'blip2')
            ImportSourceParser._parseBlips(sourceObj, wave, null, (err, blips) ->
                test.deepEqual(['blip1', 'blip2'], blips)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_parseBlip: (test) ->
            sourceData = 
                waveletData: 
                    rootThread: 
                        sdaf:"sdf"
            blipData = 
                blipId: 'GWaveBlipId1'
            blipIds = 
                'GWaveBlipId1': 'blipId1'
                'GWaveBlipId2': 'blipId2'
            waveId = 'waveId'
            wave = {
                id: waveId
                participants: []
            }
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_isRootBlip')
                .withExactArgs(blipData, sourceData.waveletData.rootThread)
                .once()
                .returns(true)
            ImportSourceParserMock
                .expects('_parseBlipContent')
                .withArgs(blipData, blipIds, sourceData)
                .once()
                .returns('content')
            ImportSourceParserMock
                .expects('_parseBlipContributors')
                .withArgs(blipData)
                .once()
                .callsArgWith(1, null, 'contributors')
            ImportSourceParser._parseBlip(wave, blipData, sourceData, blipIds, (err, blip) ->
                test.equal('blipId1', blip.id)
                test.equal(waveId, blip.waveId)
                test.equal(true, blip.isRootBlip)
                test.equal('content', blip.content)
                test.equal('contributors', blip.contributors)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_parseBlipContent: (test) ->
            sourceData = 
                waveletData: 
                    rootThread: 
                        sdaf:"sdf"
                threads: "threads"
            blipData = 
                blipId: 'GWaveBlipId1'
                content: "\nHellow   world!"
                elements:
                    "0":
                        "properties": {}
                        "type":"LINE"
                    "8":
                        "properties":
                            "id":"GWaveBlipId2"
                        "type":"INLINE_BLIP"
            blipIds = 
                'GWaveBlipId1': 'blipId1'
                'GWaveBlipId2': 'blipId2'
            ranges = [0, 1, 8, 9]
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_getSortedBlipContentRanges')
                .withExactArgs(blipData)
                .once()
                .returns(ranges)
            for i in [0..3]
                start = ranges[i]
                end = if i==3 then 16 - 1 else ranges[i+1] - 1
                ImportSourceParserMock
                    .expects('_parseBlipContentRange')
                    .withArgs(blipData, blipIds, start, end, "threads")
                    .once()
                    .returns("f#{i}")
            ImportSourceParserMock
                .expects('_findBlipReplies')
                .withExactArgs(blipData, sourceData, blipIds)
                .once()
                .returns(["r0", "r1"])
            content = ImportSourceParser._parseBlipContent(blipData, blipIds, sourceData)
            test.deepEqual(['f0','f1', 'f2', 'f3', 'r0', 'r1'], content)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        test_parseBlipContentRange: (test) ->
            code = (done, exp, startPos, endPos) ->
                blipData = 
                    blipId: 'GWaveBlipId1'
                    content: "\nHello   world!"
                    annotations: {
                    }
                    elements:
                        "0":
                            "properties": {}
                            "type":"LINE"
                        "7":
                            "properties":
                                "id":"GWaveBlipId2"
                            "type":"INLINE_BLIP"
                blipIds = 
                    'GWaveBlipId1': 'blipId1'
                    'GWaveBlipId2': 'blipId2'
                ImportSourceParserMock = sinon.mock(ImportSourceParser)
                element = blipData.elements[startPos]
                if element
                    ImportSourceParserMock
                        .expects('_getElementParams')
                        .withExactArgs(element, blipIds, 'threads')
                        .once()
                        .returns({'element': 'element'})
                else
                    ImportSourceParserMock
                        .expects('_getAnnotationsParams')
                        .withArgs(blipData.annotations, startPos, endPos)
                        .once()
                        .returns({'annotation': 'annotation'})
                fragment = ImportSourceParser._parseBlipContentRange(blipData, blipIds, startPos, endPos, 'threads')
                test.deepEqual(exp, fragment)
                sinon.verifyAll()
                sinon.restoreAll()
                done()

            dataprovider(test, [
                [{
                    t: " "
                    params: 
                        'element': 'element'
                }, 0, 0]
                [{
                    t: " "
                    params: 
                        'element': 'element'
                }, 7, 7]
                [{
                    t: "He"
                    params:
                        'annotation': 'annotation'
                }, 1, 2]
                [{
                    t: "llo"
                    params:
                        'annotation': 'annotation'
                }, 3, 5]
            ], code)

        test_findBlipReplies: (test) ->
            blipData =
                parentBlipId: 'sddfgdfg'
                threadId: 'sdfsdfsdfsdf'
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_findBlipInnerReplies')
                .withExactArgs(blipData, 'blipIds')
                .once()
                .returns(['innerReply1', 'innerReply2'])
            ImportSourceParserMock
                .expects('_findBlipThreadReplies')
                .withExactArgs(blipData, 'sourceData', 'blipIds')
                .once()
                .returns(['threadReply1', 'threadReply2'])
            replies = ImportSourceParser._findBlipReplies(blipData, 'sourceData', 'blipIds')
            test.deepEqual(['innerReply1', 'innerReply2', 'threadReply1', 'threadReply2'], replies)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
            
        test_createInlineBlipFragment: (test) ->
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_createInlineBlipFragmentParams')
                .withExactArgs('blipId')
                .once()
                .returns('params')
            fragment = ImportSourceParser._createInlineBlipFragment('blipId')
            test.deepEqual({
                t: " "
                params: "params"
            }, fragment)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        test_createInlineBlipFragmentParams: (test) ->
            fragmentParams = ImportSourceParser._createInlineBlipFragmentParams('blipId')
            test.deepEqual({
                "__TYPE": "BLIP"
                "__ID": "blipId"
            }, fragmentParams)
            test.done()

        test_findBlipInnerReplies: (test) ->
            blipData = 
                blipId: 'GWaveBlipId1'
                content: "\nHello   world!"
                annotations: {
                }
                elements:
                    "0":
                        "properties": {}
                        "type":"LINE"
                    "7":
                        "properties":
                            "id":"GWaveBlipId2"
                        "type":"INLINE_BLIP"
                replyThreadIds: ['GWaveBlipId3']
            blipIds = 
                'GWaveBlipId1': 'blipId1'
                'GWaveBlipId2': 'blipId2'
                'GWaveBlipId3': 'blipId3'
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_createInlineBlipFragment')
                .withExactArgs('blipId3')
                .once()
                .returns('fragment')

            replies = ImportSourceParser._findBlipInnerReplies(blipData, blipIds)
            test.deepEqual(['fragment'], replies)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        test_findBlipThreadReplies: (test) ->
            blipData = 
                blipId: 'GWaveBlipId1'
                threadId: 'threadId'
            blipIds = 
                'GWaveBlipId1': 'blipId1'
                'GWaveBlipId2': 'blipId2'
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('_getBlipThread')
                .withExactArgs('threadId', 'sourceData')
                .once()
                .returns({
                    blipIds: ['GWaveBlipId1', 'GWaveBlipId2']
                })
            ImportSourceParserMock
                .expects('_createSimpleLineFragment')
                .once()
                .returns('line')
            ImportSourceParserMock
                .expects('_createInlineBlipFragment')
                .withExactArgs('blipId2')
                .once()
                .returns('fragment')
            replies = ImportSourceParser._findBlipThreadReplies(blipData, 'sourceData', blipIds)
            test.deepEqual(['line', 'fragment'], replies)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        test_insertSortedElementIfNotInArray: (test) ->
            code = (done, exp, array, value) ->
                ImportSourceParser._insertSortedElementIfNotInArray(array, value)
                test.deepEqual(exp, array)
                done()
            dataprovider(test, [
                [[1, 2, 3], [1, 3], 2]
                [[1, 3], [1, 3], 3]
                [[0, 1, 3], [1, 3], 0]
            ], code)

        test_getSortedBlipContentRanges: (test) ->
            code = (done, exp, elements, annotations) ->
                blipData =
                    content: "0123456789"
                    elements: elements
                    annotations: annotations
                ranges = ImportSourceParser._getSortedBlipContentRanges(blipData)
                test.deepEqual(exp, ranges)
                done()
            dataprovider(test, [
                [
                    [0,1,2,3,4]
                    {"1": {}, "3":{}}
                    [{"range":{start: 0, end: 9}}]
                ]
                [
                    [0,1,2,3,7,9]
                    {"1": {}, "9":{}}
                    [{"range":{start: 0, end: 9}}, {"range":{start: 3, end: 6}}]
                ]
                [
                    [0,1,2,3,7]
                    {"1": {}}
                    [{"range":{start: 0, end: 9}}, {"range":{start: 3, end: 6}}]
                ]
                [
                    [0,1,2,9]
                    {"1": {}, "9":{}}
                    []
                ]
                [
                    [0,3,7]
                    {}
                    [{"range":{start: 0, end: 9}}, {"range":{start: 3, end: 6}}]
                ]
                [
                    [0,1,3,6,8]
                    {}
                    [{"range":{start: 1, end: 5}}, {"range":{start: 3, end: 7}}]
                ]
                [
                    [0,1,3,6]
                    {}
                    [{"range":{start: 1, end: 5}}, {"range":{start: 3, end: 9}}]
                ]
                [
                    [0, 1, 8]
                    { "0":{ "properties":{}, "type":"LINE"}}
                    [{
                        "range": {"start": 0, "end":7}
                        "name":"lang"
                        "value":"en"
                    }]
                ]
            ], code)

        test_getElementParams: (test) ->
            #@TODO: дореализовать
            code = (done, exp, element) ->
                blipIds = 
                    'GWaveBlipId1': 'blipId1'
                    'GWaveBlipId2': 'blipId2'
                threads = {
                    "GWaveBlipId3": {
                        "blipIds": ['GWaveBlipId2']
                    }
                }
                mock = sinon.mock(ImportSourceParser)
                mock
                    .expects('_random')
                    .once()
                    .returns('random')
                res = ImportSourceParser._getElementParams(element, blipIds, threads)
                test.deepEqual(exp, res)
                sinon.verifyAll()
                sinon.restoreAll()
                done()
            
            dataprovider(test, [
                [{
                    "__TYPE": "BLIP"
                    "__ID": "blipId2"
                }, {
                    "type": "INLINE_BLIP"
                    "properties": {
                        "id": "GWaveBlipId3"
                    }
                }],
                [{
                    "__TYPE": "BLIP"
                    "__ID": "blipId2"
                }, {
                    "type": "INLINE_BLIP"
                    "properties": {
                        "id": "GWaveBlipId2"
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                }, {
                    "type": "LINE"
                    "properties": {                        
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                    "L_BULLETED": 1
                }, {
                    "type": "LINE"
                    "properties": {
                        "indent": "1"
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                    "L_BULLETED": 2
                }, {
                    "type": "LINE"
                    "properties": {
                        "indent": "2"
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                    "L_BULLETED": 0
                }, {
                    "type": "LINE"
                    "properties": {
                        "lineType": "li"
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                    "L_BULLETED": 0
                }, {
                    "type": "LINE"
                    "properties": {
                        "lineType": "li"
                        "indent": "0"
                    }
                }],
                [{
                    "__TYPE": "LINE"
                    "RANDOM": "random"
                    "L_BULLETED": 2
                }, {
                    "type": "LINE"
                    "properties": {
                        "lineType": "li"
                        "indent": "2"
                    }
                }],
                [{
                    "__TYPE": "ATTACHMENT"
                    "__URL": "http://url.img/"
                }, {
                    "type": "ATTACHMENT"
                    "properties": {
                        "attachmentUrl": "http://url.img/"
                    }
                }],
                [{
                    "__TYPE": "GADGET"
                    "author":"vsemenov86@googlewave.com"
                    "url":"http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml"
                    "ifr":"//g1qqb4lp5hrcfvk0vuhb70127nchupuh-a-wave-opensocial.googleusercontent.com/gadgets/ifr?url=http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml&container=wave&view=default&sanitize=0&v=e3fbcf147e789522&libs=core:dynamic-height:opensocial-data:opensocial-templates:wave"
                }, {
                    "properties":{
                        "author":"vsemenov86@googlewave.com",
                        "url":"http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml",
                        "ifr":"//g1qqb4lp5hrcfvk0vuhb70127nchupuh-a-wave-opensocial.googleusercontent.com/gadgets/ifr?url=http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml&container=wave&view=default&sanitize=0&v=e3fbcf147e789522&libs=core:dynamic-height:opensocial-data:opensocial-templates:wave"
                    },
                    "type":"GADGET"
                }],
                [{}, {
                    "properties":{
                        "author":"vsemenov86@googlewave.com",
                        "url":"http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml",
                        "ifr":"//g1qqb4lp5hrcfvk0vuhb70127nchupuh-a-wave-opensocial.googleusercontent.com/gadgets/ifr?url=http://wave-api.appspot.com/public/gadgets/areyouin/gadget.xml&container=wave&view=default&sanitize=0&v=e3fbcf147e789522&libs=core:dynamic-height:opensocial-data:opensocial-templates:wave"
                    },
                    "type":"RECIPIENT"
                }]
            ], code)

        test_getAnnotationParams: (test) ->
            #@TODO: дореализовать
            code = (done, exp, annotation) ->
                res = ImportSourceParser._getAnnotationParams(annotation)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                [{"T_BOLD": true}, {"name": "style/fontWeight", "value": "bold"}]
                [{"T_ITALIC": true}, {"name": "style/fontStyle", "value": "italic"}]
                [{"T_UNDERLINED": true}, {"name": "style/textDecoration", "value": "underline"}]
                [{"T_STRUCKTHROUGH": true}, {"name": "style/textDecoration", "value": "line-through"}]
                [{"T_URL": "http://localhost"}, {"name": "link/manual", "value": "http://localhost"}]
                [{"T_URL": "http://localhost"}, {"name": "link/wave", "value": "http://localhost"}]
                [{"T_URL": "http://localhost"}, {"name": "link/auto", "value": "http://localhost"}]
            ], code)

        test_getAnnotationsParams: (test) ->
            annotations = [
                {
                    name: "link/manual"
                    value: "http://localhost"
                    range: {
                        start: 0
                        end: 3
                    }
                },
                {
                    name: "style/fontWeight"
                    value: "bold"
                    range: {
                        start: 0
                        end: 3
                    }
                }
            ]
            res = ImportSourceParser._getAnnotationsParams(annotations, 0, 3)
            test.deepEqual({"__TYPE": "TEXT", "T_URL": "http://localhost", "T_BOLD": true}, res)
            test.done()

        test_parseLink: (test) ->
            code = (done, exp, link) ->
                res = ImportSourceParser._parseLink(link)
                test.equal(exp, res)
                done()
            dataprovider(test, [
                ['http://localhost', 'http://localhost']
                ["#{LINK_REDIRECT_PREFIX}googlewave.com/w+sVBcmzVLA/conv+root/b+sVBcmzVLF", 'waveid://googlewave.com/w+sVBcmzVLA/~/conv+root/b+sVBcmzVLF']
                [
                    "#{LINK_REDIRECT_PREFIX}googlewave.com/w+sVBcmzVLA/conv+root/b+sVBcmzVLF",
                    'https://wave.google.com/wave/waveref/googlewave.com/w+sVBcmzVLA/~/conv+root/b+sVBcmzVLF'
                ]
            ], code)
            
        test_isEmailToSkip: (test) ->
            code = (done, exp, email) ->
                res = ImportSourceParser._isEmailToSkip(email)
                test.equal(exp, res)
                done()
            dataprovider(test, [
                [false, 'test@googlewave.com']
                [false, 'test@gmail.com']
                [true, 'test@appspot.com']
                [false, 'public@googlewave.com']
                [true, 'public@appspot.com']
                [true, 'public@a.gwave.com']
                [true, 'sdg@invite.gwave.com']
            ], code)

        test_findRootThreadReplies: (test) ->