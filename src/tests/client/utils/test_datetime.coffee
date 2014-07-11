testCase = require('nodeunit').testCase
datetime = require('../../../client/utils/datetime')
getFormat = require('../../../client/utils/datetime')._getFormat
getFormattedDate = require('../../../client/utils/datetime')._getFormattedDate
dataprovider = require('dataprovider')

module.exports =
    DatetimeTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFormatDate: (test) ->
            testCode = (done, serverDate, clientToday, format) =>
                ###
                @param serverDate: Date - дата пришедшая с сревера;
                @param clientToday: Date - текущая дата на клиенте;
                @param format: String - результат выполнения функции.
                ###
                test.equal(datetime._getFormat(serverDate, clientToday), format)
                done()

            testCases = [
                #момент t был сегодня (после 00:00 в пользовательском часовом поясе) - возвращаем время 
                [
                    new Date('1 Jan 2012 1:00'),
                    new Date('1 Jan 2012 4:00'),
                    datetime._TIME_SHORT
                ],
                #с момента t прошло меньше 2 часов
                [
                    new Date('1 Jan 2012 23:00'),
                    new Date('2 Jan 2012 0:59'),
                    datetime._TIME_SHORT
                ],
                #момент t в этом году
                [
                    new Date('1 Jan 2012 23:00'),
                    new Date('5 Jan 2012 0:59'),
                    datetime._DATE_SHORT
                ],
                #момент t был в прошлом году (по пользовательскому календарю/часовому поясу) но с него прошло менее 60 дней
                [
                    new Date('1 Dec 2011 23:00'),
                    new Date('5 Jan 2012 0:59'),
                    datetime._DATE_SHORT
                ],
                #момент t в прошлом году и прошло более 60 дней
                [
                    new Date('31 Oct 2011 0:59'),
                    new Date('1 Jan 2012 23:00'),
                    datetime._DATE
                ]
            ]
            dataprovider(test, testCases, testCode)