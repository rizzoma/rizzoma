global.getLogger = () ->
    return {error: ->}
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
Conf = require('../../../server/conf').Conf
WaveController = require('../../../server/wave/controller').WaveController
dataprovider = require('dataprovider')

module.exports =
    WaveControllerTest: testCase
        setUp: (callback) ->
            @_random = Math.random
            Math.random = () ->
                return 'random'
            @_now = Date.now
            Date.now = () ->
                return 2921373998467
            callback()

        tearDown: (callback) ->
            Math.random = @_random
            Date.now = @_now
            callback()

        test_parseWelcomeTemplateBlipContentTextFragment: (test) ->
            code = (done, exp, fragment) ->
                content = WaveController._parseWelcomeTemplateBlipContentTextFragment(fragment, {id: '0_u_2'}, '0_u_e')
                test.deepEqual(exp, content)
                done()
            dataprovider(test,[
                [
                    [{
                        t: 'Это тупо текст фрагмента блипа'
                        params:
                            __TYPE: 'TEXT'
                            __BOLD: true
                    }]
                    {
                        t: 'Это тупо текст фрагмента блипа'
                        params:
                            __TYPE: 'TEXT'
                            __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                        t: 'Это текст c *@* фрагмента блипа'
                        params:
                            __TYPE: 'TEXT'
                            __BOLD: true
                    }
                ]
                [
                    [
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                    ]
                    {
                    t: '*@*'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: '*@* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                    ]
                    {
                    t: 'Это текст c *@*'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: 'Это текст c *@* *@* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: 'Это текст c *@**@* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' ', params: { __TYPE: 'TASK', recipientId: '0_u_e', senderId: '0_u_2', status: 1, RANDOM: 'random' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: 'Это текст c *@**~* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'RECIPIENT', __ID: '0_u_e', RANDOM: 'random' } },
                        { t: ' ', params: { __TYPE: 'TEXT', __BOLD: true } }
                        { t: ' ', params: { __TYPE: 'TASK', recipientId: '0_u_e', senderId: '0_u_2', status: 1, RANDOM: 'random', deadlineDate: '2062-07-29' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: 'Это текст c *@* *~+0* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
                [
                    [
                        { t: 'Это текст c ', params: { __TYPE: 'TEXT', __BOLD: true } },
                        { t: ' ', params: { __TYPE: 'TASK', recipientId: '0_u_e', senderId: '0_u_2', status: 1, RANDOM: 'random', deadlineDate: '2062-08-08' } },
                        { t: ' фрагмента блипа', params: { __TYPE: 'TEXT', __BOLD: true } }
                    ]
                    {
                    t: 'Это текст c *~+10* фрагмента блипа'
                    params:
                        __TYPE: 'TEXT'
                        __BOLD: true
                    }
                ]
            ], code)