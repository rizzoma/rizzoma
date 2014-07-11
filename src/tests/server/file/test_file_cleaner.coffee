sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
FileCleaner = require('../../../server/file/file_cleaner').FileCleaner
dataprovider = require('dataprovider')

module.exports =
    FileCleanerTest: testCase
        setUp: (callback) ->
            @fileCleaner = new FileCleaner
            callback()

        testGetFilesForProcessing0: (test) ->
            test.deepEqual([], @fileCleaner._getFilesForProcessing([]))
            test.done()

        testGetFilesForProcessing1: (test) ->
            files = [{
                id: '1'
                key: 'f1'
                value: { type: 'link' }
            },{
                id: 'f2'
                key: 'f2'
                value: { type: 'link' }
            }]
            test.deepEqual([], @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing2: (test) ->
            files = [{
                id: 'b1'
                key: 'f1'
                value: { type: 'link' }
            },
            {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: yes }
            }]

            res = [{
                fileId: 'f1'
                found: yes
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing3: (test) ->
            files = [{
                id: 'b1'
                key: 'f1'
                value: { type: 'link' }
            },
            {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: no }
            }]

            res = []

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing4: (test) ->
            files = [{
                id: 'b1'
                key: 'f1'
                value: { type: 'link' }
            },
            {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: no }
            },{
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }]

            res = [{
                fileId: 'f2'
                found: no
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing5: (test) ->
            files = [{
                id: 'b1'
                key: 'f1'
                value: { type: 'link' }
            },{
                id: 'b2'
                key: 'f1'
                value: { type: 'link' }
            },{
                id: 'b3'
                key: 'f1'
                value: { type: 'link' }
            },
            {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: yes }
            },{
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }]

            res = [{
                fileId: 'f1'
                found: yes
            },{
                fileId: 'f2'
                found: no
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing6: (test) ->
            files = [{
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: no }
            },{
                id: 'b1'
                key: 'f2'
                value: { type: 'link' }
            },{
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: yes }
            }]

            res = [{
                fileId: 'f1'
                found: no
            }, {
                fileId: 'f2'
                found: yes
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing7: (test) ->
            files = [{
                id: 'b1'
                key: 'f1'
                value: { type: 'link' }
            }, {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: no }
            },{
                id: 'b1'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'b2'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }]

            res = []

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing8: (test) ->
            files = [{
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b3'
                key: 'f5'
                value: { type: 'link' }
            }, {
                id: 'b4'
                key: 'f6'
                value: { type: 'link' }
            },{
                id: 'f7'
                key: 'f7'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b5'
                key: 'f7'
                value: { type: 'link' }
            }, {
                id: 'f8'
                key: 'f8'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b3'
                key: 'f8'
                value: { type: 'link' }
            }, {
                id: 'b4'
                key: 'f9'
                value: { type: 'link' }
            }]

            res = [{
                fileId: 'f1'
                found: no
            }, {
                fileId: 'f2'
                found: no
            }, {
                fileId: 'f7'
                found: yes
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing9: (test) ->
            files = [{
                id: 'b666'
                key: 'f1'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f1'
                value: { type: 'link' }
            }, {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b666'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'f3'
                key: 'f3'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b666'
                key: 'f3'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f3'
                value: { type: 'link' }
            }, {
                id: 'f4'
                key: 'f4'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b666'
                key: 'f4'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f4'
                value: { type: 'link' }
            }, {
                id: 'b3'
                key: 'f5'
                value: { type: 'link' }
            }, {
                id: 'f5'
                key: 'f5'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b8'
                key: 'f5'
                value: { type: 'link' }
            }, {
                id: 'b3'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'f6'
                key: 'f6'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b8'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'b4'
                key: 'f6'
                value: { type: 'link' }
            },{
                id: 'f7'
                key: 'f7'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'f8'
                key: 'f8'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b3'
                key: 'f9'
                value: { type: 'link' }
            }, {
                id: 'f9'
                key: 'f9'
                value: { type: 'file', linkNotFound: no }
            }]

            res = [{
                fileId: 'f1'
                found: yes
            }, {
                fileId: 'f4'
                found: yes
            }, {
                fileId: 'f5'
                found: yes
            }, {
                fileId: 'f7'
                found: no
            }, {
                fileId: 'f8'
                found: no
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing10: (test) ->
            files = [{
                id: 'b666'
                key: 'f1'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f1'
                value: { type: 'link' }
            }, {
                id: 'f1'
                key: 'f1'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b666'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f2'
                value: { type: 'link' }
            }, {
                id: 'f2'
                key: 'f2'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'f3'
                key: 'f3'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b666'
                key: 'f3'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f3'
                value: { type: 'link' }
            }, {
                id: 'f4'
                key: 'f4'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b666'
                key: 'f4'
                value: { type: 'link' }
            }, {
                id: 'b777'
                key: 'f4'
                value: { type: 'link' }
            }, {
                id: 'b3'
                key: 'f5'
                value: { type: 'link' }
            }, {
                id: 'f5'
                key: 'f5'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'b8'
                key: 'f5'
                value: { type: 'link' }
            }, {
                id: 'b3'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'f6'
                key: 'f6'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b8'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'b4'
                key: 'f6'
                value: { type: 'link' }
            },{
                id: 'f7'
                key: 'f7'
                value: { type: 'file', linkNotFound: yes }
            }, {
                id: 'f8'
                key: 'f8'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'f9'
                key: 'f9'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b3'
                key: 'f9'
                value: { type: 'link' }
            }]

            res = [{
                fileId: 'f1'
                found: yes
            }, {
                fileId: 'f4'
                found: yes
            }, {
                fileId: 'f5'
                found: yes
            }, {
                fileId: 'f7'
                found: no
            }, {
                fileId: 'f8'
                found: no
            }]

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()

        testGetFilesForProcessing11: (test) ->
            files = [{
                id: 'b3'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'f6'
                key: 'f6'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b8'
                key: 'f6'
                value: { type: 'link' }
            }, {
                id: 'f7'
                key: 'f7'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b4'
                key: 'f7'
                value: { type: 'link' }
            }, {
                id: 'b4'
                key: 'f8'
                value: { type: 'link' }
            }, {
                id: 'f8'
                key: 'f8'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'f9'
                key: 'f9'
                value: { type: 'file', linkNotFound: no }
            }, {
                id: 'b3'
                key: 'f9'
                value: { type: 'link' }
            }]

            res = []

            test.deepEqual(res, @fileCleaner._getFilesForProcessing(files))
            test.done()
